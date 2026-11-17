import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/token_service.dart';

class ProductSalesScreen extends StatefulWidget {
  const ProductSalesScreen({super.key, this.openSaleOnOpen = false});

  final bool openSaleOnOpen;

  @override
  State<ProductSalesScreen> createState() => _ProductSalesScreenState();
}

class _ProductSalesScreenState extends State<ProductSalesScreen> {
  static const String _defaultProductCategory = 'phone_accessory';

  List<dynamic> products = [];
  List<dynamic> sales = [];

  bool isLoading = true;
  bool isRefreshing = false;
  bool salesPermissionDenied = false;
  bool _autoOpenedSale = false;
  bool _openingSaleDialog = false;
  String? salesErrorMessage;
  String? errorMessage;
  String? _saleDialogLoadError;

  @override
  void initState() {
    super.initState();
    fetchProductData();
  }

  Future<void> fetchProductData({bool refresh = false}) async {
    setState(() {
      if (refresh) {
        isRefreshing = true;
      } else {
        isLoading = true;
      }
      salesPermissionDenied = false;
      salesErrorMessage = null;
      errorMessage = null;
    });

    try {
      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();

      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      final inventoryResponse = await ApiService.get(
        '/businesses/$businessId/inventory',
        token: token,
      );
      final inventoryItems = inventoryResponse['items'];
      if (inventoryItems is! List) {
        throw Exception('Unable to load inventory products.');
      }

      List<dynamic> productSales = [];
      String? loadedSalesError;
      var isSalesPermissionDenied = false;
      try {
        final salesResponse = await ApiService.get(
          '/businesses/$businessId/product-sales',
          token: token,
        );
        final salesList = salesResponse['sales'];
        if (salesList is! List) {
          throw Exception('Unable to load product sales.');
        }
        productSales = List<dynamic>.from(salesList);
      } catch (error) {
        isSalesPermissionDenied =
            error is ApiException &&
            error.statusCode == 403 &&
            error.message ==
                'You do not have permission to perform this action';
        loadedSalesError = isSalesPermissionDenied
            ? 'Product sales history is available only to owners and managers. '
                  'You can still record a product sale.'
            : error.toString().replaceFirst('Exception: ', '');
      }

      if (!mounted) return;

      setState(() {
        products = List<dynamic>.from(inventoryItems);
        sales = productSales;
        salesPermissionDenied = isSalesPermissionDenied;
        salesErrorMessage = loadedSalesError;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });

        if (widget.openSaleOnOpen && !_autoOpenedSale) {
          _autoOpenedSale = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            if (errorMessage != null) {
              setState(() {
                _saleDialogLoadError = errorMessage;
              });
              return;
            }

            setState(() {
              _openingSaleDialog = true;
            });
            await showRecordSaleDialog();
            if (mounted) Navigator.of(context).pop();
          });
        }
      }
    }
  }

  Future<void> showRecordSaleDialog() async {
    final formKey = GlobalKey<FormState>();
    final saleQuantityController = TextEditingController(text: '1');
    final productNameController = TextEditingController();
    final productNameFocusNode = FocusNode();
    final costPriceController = TextEditingController();
    final sellingPriceController = TextEditingController();
    final openingStockController = TextEditingController();

    final availableProducts = _availableProducts();
    final firstProductId = availableProducts.isEmpty
        ? null
        : _productId(availableProducts.first);
    String saleType = firstProductId == null ? 'new' : 'existing';
    String? selectedItemId = firstProductId;
    final firstProduct = firstProductId == null
        ? null
        : _findProductById(firstProductId);
    if (firstProduct != null) {
      productNameController.text = firstProduct['name']?.toString() ?? '';
      costPriceController.text = firstProduct['costPrice']?.toString() ?? '';
      sellingPriceController.text =
          firstProduct['sellingPrice']?.toString() ?? '';
    }
    bool isSubmitting = false;
    String? submissionError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContentContext, setDialogState) {
            final selectedProduct = _findProductById(selectedItemId);
            final quantity =
                int.tryParse(saleQuantityController.text.trim()) ?? 0;
            final unitPrice = saleType == 'existing'
                ? _parseAmount(selectedProduct?['sellingPrice'])
                : _parseAmount(sellingPriceController.text);

            Map<dynamic, dynamic>? findProductByName(String name) {
              final normalizedName = name.trim().toLowerCase();
              if (normalizedName.isEmpty) return null;
              for (final product in availableProducts) {
                if (product['name']?.toString().trim().toLowerCase() ==
                    normalizedName) {
                  return product;
                }
              }
              return null;
            }

            void selectProduct(Map<dynamic, dynamic> product) {
              selectedItemId = _productId(product);
              productNameController.text = product['name']?.toString() ?? '';
              costPriceController.text = product['costPrice']?.toString() ?? '';
              sellingPriceController.text =
                  product['sellingPrice']?.toString() ?? '';
            }

            Widget productNameField({required String label}) {
              return RawAutocomplete<String>(
                textEditingController: productNameController,
                focusNode: productNameFocusNode,
                displayStringForOption: (option) => option,
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();
                  if (query.isEmpty) return const Iterable<String>.empty();
                  return availableProducts
                      .map((product) => product['name']?.toString())
                      .whereType<String>()
                      .where((name) => name.toLowerCase().contains(query))
                      .toSet();
                },
                onSelected: (name) {
                  final product = findProductByName(name);
                  if (product == null) return;
                  setDialogState(() {
                    saleType = 'existing';
                    selectProduct(product);
                    submissionError = null;
                  });
                },
                fieldViewBuilder:
                    (_, textController, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: textController,
                        focusNode: focusNode,
                        enabled: !isSubmitting,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: label,
                          prefixIcon: const Icon(Icons.search),
                        ),
                        validator: (value) {
                          if (saleType == 'existing') {
                            return selectedItemId == null
                                ? 'Select an inventory product.'
                                : null;
                          }
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter a product name.';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          final match = findProductByName(value);
                          setDialogState(() {
                            if (match != null) {
                              saleType = 'existing';
                              selectProduct(match);
                            } else if (saleType == 'existing') {
                              selectedItemId = null;
                              costPriceController.clear();
                              sellingPriceController.clear();
                            }
                            submissionError = null;
                          });
                        },
                        onFieldSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      color: Colors.white,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 220,
                          maxWidth: 520,
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: options
                              .map(
                                (name) => ListTile(
                                  dense: true,
                                  title: Text(name),
                                  onTap: () => onSelected(name),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            Future<void> submitSale() async {
              if (!formKey.currentState!.validate()) return;

              final saleQuantity = int.parse(
                saleQuantityController.text.trim(),
              );
              final request = <String, dynamic>{
                'quantity': saleQuantity,
                'paymentMethod': 'cash',
                'paymentStatus': 'paid',
              };

              if (saleType == 'existing') {
                if (selectedProduct == null || selectedItemId == null) {
                  setDialogState(() {
                    submissionError = 'Select an inventory product to sell.';
                  });
                  return;
                }
                request['itemId'] = selectedItemId;
              } else {
                request['newProduct'] = {
                  'name': productNameController.text.trim(),
                  'category': _defaultProductCategory,
                  'costPrice': double.parse(costPriceController.text.trim()),
                  'sellingPrice': double.parse(
                    sellingPriceController.text.trim(),
                  ),
                  'openingStock': int.parse(openingStockController.text.trim()),
                };
              }

              setDialogState(() {
                isSubmitting = true;
                submissionError = null;
              });

              try {
                final token = await TokenService.getToken();
                final businessId = await TokenService.getBusinessId();

                if (token == null || businessId == null) {
                  throw Exception(
                    'Login information not found. Please log in again.',
                  );
                }

                final response = await ApiService.post(
                  '/businesses/$businessId/product-sales',
                  request,
                  token: token,
                );

                final responseData = response is Map ? response['data'] : null;
                final calculation = responseData is Map
                    ? responseData['calculation']
                    : null;
                final totalAmount = calculation is Map
                    ? calculation['totalAmount']
                    : null;

                if (!dialogContentContext.mounted) return;
                Navigator.pop(dialogContentContext);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Product sale recorded. Total: '
                      '${_formatCurrency(totalAmount ?? unitPrice * saleQuantity)}',
                    ),
                  ),
                );
                await fetchProductData(refresh: true);
              } catch (error) {
                if (!dialogContentContext.mounted) return;

                setDialogState(() {
                  submissionError = error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  );
                });
              } finally {
                if (dialogContentContext.mounted) {
                  setDialogState(() {
                    isSubmitting = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Record Product Sale'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: saleType,
                          decoration: const InputDecoration(
                            labelText: 'Sale Type',
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: 'existing',
                              enabled: availableProducts.isNotEmpty,
                              child: const Text('Existing inventory product'),
                            ),
                            const DropdownMenuItem<String>(
                              value: 'new',
                              child: Text('Add a new product'),
                            ),
                          ],
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  if (value == 'new') {
                                    productNameController.clear();
                                    costPriceController.clear();
                                    sellingPriceController.clear();
                                    openingStockController.clear();
                                    selectedItemId = null;
                                  } else if (firstProduct != null) {
                                    selectProduct(firstProduct);
                                  }
                                  setDialogState(() {
                                    saleType = value;
                                    submissionError = null;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        if (saleType == 'existing') ...[
                          if (availableProducts.isEmpty)
                            const Text(
                              'No inventory products found. Choose a new product instead.',
                              style: TextStyle(color: Colors.grey),
                            )
                          else
                            productNameField(
                              label: 'Search inventory products',
                            ),
                          if (selectedProduct != null) ...[
                            const SizedBox(height: 12),
                            _buildSaleSummary(
                              unitPrice: unitPrice,
                              quantity: quantity,
                              stockLabel:
                                  'Available stock: ${selectedProduct['quantityInStock'] ?? 0}',
                            ),
                          ],
                        ] else ...[
                          productNameField(
                            label: 'Product name (search or add new)',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: costPriceController,
                            enabled: !isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Cost Price (KSh)',
                            ),
                            validator: (value) {
                              final amount = double.tryParse(
                                value?.trim() ?? '',
                              );
                              if (amount == null ||
                                  !amount.isFinite ||
                                  amount < 0) {
                                return 'Enter a valid cost price.';
                              }
                              return null;
                            },
                            onChanged: (_) => setDialogState(() {
                              submissionError = null;
                            }),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: sellingPriceController,
                            enabled: !isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Selling Price (KSh)',
                            ),
                            validator: (value) {
                              final amount = double.tryParse(
                                value?.trim() ?? '',
                              );
                              if (amount == null ||
                                  !amount.isFinite ||
                                  amount < 0) {
                                return 'Enter a valid selling price.';
                              }
                              return null;
                            },
                            onChanged: (_) => setDialogState(() {
                              submissionError = null;
                            }),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: openingStockController,
                            enabled: !isSubmitting,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Opening Stock',
                            ),
                            validator: (value) {
                              final stock = int.tryParse(value?.trim() ?? '');
                              if (stock == null || stock < 1) {
                                return 'Enter a positive opening stock quantity.';
                              }
                              return null;
                            },
                            onChanged: (_) => setDialogState(() {
                              submissionError = null;
                            }),
                          ),
                          const SizedBox(height: 12),
                          _buildSaleSummary(
                            unitPrice: unitPrice,
                            quantity: quantity,
                            stockLabel:
                                'Opening stock: ${openingStockController.text.isEmpty ? '—' : openingStockController.text}',
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: saleQuantityController,
                          enabled: !isSubmitting,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity to Sell',
                          ),
                          validator: (value) {
                            final saleQuantity = int.tryParse(
                              value?.trim() ?? '',
                            );
                            if (saleQuantity == null || saleQuantity < 1) {
                              return 'Enter a positive whole quantity.';
                            }

                            if (saleType == 'existing' &&
                                selectedProduct != null &&
                                saleQuantity >
                                    _parseInteger(
                                      selectedProduct['quantityInStock'],
                                    )) {
                              return 'Quantity exceeds available stock.';
                            }

                            if (saleType == 'new') {
                              final openingStock = int.tryParse(
                                openingStockController.text.trim(),
                              );
                              if (openingStock != null &&
                                  saleQuantity > openingStock) {
                                return 'Quantity cannot exceed opening stock.';
                              }
                            }
                            return null;
                          },
                          onChanged: (_) => setDialogState(() {
                            submissionError = null;
                          }),
                        ),
                        if (submissionError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            submissionError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submitSale,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Record Sale'),
                ),
              ],
            );
          },
        );
      },
    );

    saleQuantityController.dispose();
    productNameController.dispose();
    productNameFocusNode.dispose();
    costPriceController.dispose();
    sellingPriceController.dispose();
    openingStockController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.openSaleOnOpen) {
      if (_saleDialogLoadError != null) {
        return AlertDialog(
          title: const Text('Unable to start sale'),
          content: Text(_saleDialogLoadError!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }

      if (_openingSaleDialog) return const SizedBox.shrink();

      return const AlertDialog(
        title: Text('Loading products'),
        content: LinearProgressIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Sales'),
        actions: [
          if (isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh product sales',
              onPressed: isLoading
                  ? null
                  : () => fetchProductData(refresh: true),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: () => fetchProductData(refresh: true),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final content = constraints.maxWidth >= 900
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildInventorySection()),
                            const SizedBox(width: 20),
                            Expanded(child: _buildSalesSection()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildInventorySection(),
                            const SizedBox(height: 24),
                            _buildSalesSection(),
                          ],
                        );

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: content,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : showRecordSaleDialog,
        icon: const Icon(Icons.point_of_sale),
        label: const Text('Record Sale'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: fetchProductData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inventory',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          _buildEmptyState('No inventory products found.')
        else
          ...products.map(_buildProductCard),
      ],
    );
  }

  Widget _buildSalesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Product Sales',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (salesErrorMessage != null)
          _buildSalesErrorState()
        else if (sales.isEmpty)
          _buildEmptyState('No product sales recorded yet.')
        else
          ...sales.map(_buildSaleCard),
      ],
    );
  }

  Widget _buildSalesErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              salesErrorMessage!,
              style: TextStyle(
                color: salesPermissionDenied
                    ? Colors.grey.shade700
                    : Colors.red,
              ),
            ),
            if (!salesPermissionDenied) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => fetchProductData(refresh: true),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    if (product is! Map) return const SizedBox.shrink();

    final name = product['name']?.toString() ?? 'Unnamed product';
    final category = product['category']?.toString().replaceAll('_', ' ');
    final quantity = product['quantityInStock']?.toString() ?? '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE3F2FD),
          child: Icon(Icons.inventory_2, color: Color(0xFF1565C0)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${category == null || category.isEmpty ? 'Product' : category}\n'
          'Stock: $quantity',
        ),
        trailing: Text(
          _formatCurrency(product['sellingPrice']),
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
      ),
    );
  }

  Widget _buildSaleCard(dynamic sale) {
    if (sale is! Map) return const SizedBox.shrink();

    final item = sale['item'];
    final productName =
        sale['productName']?.toString() ??
        (item is Map ? item['name']?.toString() : null) ??
        'Unknown Product';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE3F2FD),
          child: Icon(Icons.receipt_long, color: Color(0xFF1565C0)),
        ),
        title: Text(
          productName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Text(
          'Total: ${_formatCurrency(sale['totalAmount'])}',
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Text(message, style: const TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildSaleSummary({
    required double unitPrice,
    required int quantity,
    required String stockLabel,
  }) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selling price: ${_formatCurrency(unitPrice)}'),
            const SizedBox(height: 4),
            Text(stockLabel),
            const Divider(),
            Text(
              'Estimated total: ${_formatCurrency(unitPrice * quantity)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<dynamic, dynamic>> _availableProducts() {
    final available = <Map<dynamic, dynamic>>[];
    for (final product in products) {
      if (product is Map && product['_id'] != null) {
        available.add(product);
      }
    }
    return available;
  }

  Map<dynamic, dynamic>? _findProductById(String? id) {
    if (id == null) return null;
    for (final product in _availableProducts()) {
      if (_productId(product) == id) return product;
    }
    return null;
  }

  String? _productId(dynamic product) {
    if (product is! Map) return null;
    return product['_id']?.toString();
  }

  int _parseInteger(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatCurrency(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');

    if (amount == null) return 'KSh —';

    final formattedAmount = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return 'KSh $formattedAmount';
  }
}
