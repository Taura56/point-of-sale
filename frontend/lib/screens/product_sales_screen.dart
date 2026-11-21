import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/token_service.dart';

class ProductSalesScreen extends StatefulWidget {
  const ProductSalesScreen({
    super.key,
    this.openSaleOnOpen = false,
    this.isMtush = false,
  });

  final bool openSaleOnOpen;
  final bool isMtush;

  @override
  State<ProductSalesScreen> createState() => _ProductSalesScreenState();
}

class _ProductSalesScreenState extends State<ProductSalesScreen> {
  static const String _defaultProductCategory = 'phone_accessory';
  static const Map<String, String> _mtushCategories = {
    'mens_clothing': "Men's clothing",
    'womens_clothing': "Women's clothing",
    'unisex_clothing': 'Unisex clothing',
    'mens_shoes': "Men's shoes",
    'womens_shoes': "Women's shoes",
    'other': 'Other',
  };
  static const Map<String, String> _mtushGenders = {
    'mens': 'Men',
    'womens': 'Women',
    'unisex': 'Unisex',
    'other': 'Other',
  };
  static const Map<String, String> _mtushProductTypes = {
    'trousers': 'Trousers',
    'shirts': 'Shirts',
    't_shirts': 'T-shirts',
    'dresses': 'Dresses',
    'tops': 'Tops',
    'skirts': 'Skirts',
    'jackets': 'Jackets',
    'sweaters': 'Sweaters',
    'shoes': 'Shoes',
    'other': 'Other',
  };
  final TextEditingController _productSearchController =
      TextEditingController();

  List<dynamic> products = [];
  List<dynamic> sales = [];

  bool isLoading = true;
  bool isRefreshing = false;
  bool salesPermissionDenied = false;
  bool _autoOpenedSale = false;
  bool _openingSaleDialog = false;
  String _productSearchQuery = '';
  String? salesErrorMessage;
  String? errorMessage;
  String? _saleDialogLoadError;

  @override
  void dispose() {
    _productSearchController.dispose();
    super.dispose();
  }

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

  Future<void> showRecordSaleDialog({String? initialItemId}) async {
    final formKey = GlobalKey<FormState>();
    final saleQuantityController = TextEditingController(text: '1');
    final productNameController = TextEditingController();
    final productNameFocusNode = FocusNode();
    final costPriceController = TextEditingController();
    final sellingPriceController = TextEditingController();
    final actualSellingPriceController = TextEditingController();
    final openingStockController = TextEditingController();
    final sizeController = TextEditingController();
    final colorController = TextEditingController();
    final conditionController = TextEditingController();

    final availableProducts = _availableProducts();
    final selectedInitialProduct =
        availableProducts
            .where((product) => _productId(product) == initialItemId)
            .firstOrNull ??
        (availableProducts.isEmpty ? null : availableProducts.first);
    final firstProductId = _productId(selectedInitialProduct);
    String saleType = widget.isMtush || firstProductId != null
        ? 'existing'
        : 'new';
    String? selectedItemId = firstProductId;
    String newProductCategory = 'mens_clothing';
    String newProductGender = 'mens';
    String newProductType = 'other';
    final firstProduct = firstProductId == null
        ? null
        : _findProductById(firstProductId);
    if (firstProduct != null) {
      productNameController.text = firstProduct['name']?.toString() ?? '';
      costPriceController.text = firstProduct['costPrice']?.toString() ?? '';
      sellingPriceController.text =
          firstProduct['sellingPrice']?.toString() ?? '';
      actualSellingPriceController.text =
          firstProduct['sellingPrice']?.toString() ?? '';
    }
    String paymentMethod = 'cash';
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
                ? (widget.isMtush
                      ? _parseAmount(actualSellingPriceController.text)
                      : _parseAmount(selectedProduct?['sellingPrice']))
                : (widget.isMtush
                      ? _parseAmount(actualSellingPriceController.text)
                      : _parseAmount(sellingPriceController.text));
            final unitCost = saleType == 'existing'
                ? _parseAmount(selectedProduct?['costPrice'])
                : _parseAmount(costPriceController.text);
            final unitProfit = unitPrice - unitCost;

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
              actualSellingPriceController.text =
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
                'paymentMethod': paymentMethod,
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
                if (widget.isMtush) {
                  request['sellingPrice'] = double.parse(
                    actualSellingPriceController.text.trim(),
                  );
                }
              } else {
                request['newProduct'] = {
                  'name': productNameController.text.trim(),
                  'category': widget.isMtush
                      ? newProductCategory
                      : _defaultProductCategory,
                  'costPrice': double.parse(costPriceController.text.trim()),
                  'sellingPrice': double.parse(
                    sellingPriceController.text.trim(),
                  ),
                  'openingStock': int.parse(openingStockController.text.trim()),
                  if (widget.isMtush) ...{
                    'gender': newProductGender,
                    'productType': newProductType,
                    'size': sizeController.text.trim(),
                    'color': colorController.text.trim(),
                    'condition': conditionController.text.trim(),
                  },
                };
                if (widget.isMtush) {
                  request['sellingPrice'] = double.parse(
                    actualSellingPriceController.text.trim(),
                  );
                }
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
                final profitAmount = calculation is Map
                    ? calculation['profitAmount']
                    : null;

                if (!dialogContentContext.mounted) return;
                Navigator.pop(dialogContentContext);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Product sale recorded. Total profit: '
                      '${_formatCurrency(profitAmount ?? unitProfit * saleQuantity)}',
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
              title: Text(
                widget.isMtush ? 'New product sale' : 'Record Product Sale',
              ),
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
                            labelText: 'Sale type',
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: 'existing',
                              enabled: availableProducts.isNotEmpty,
                              child: Text(
                                widget.isMtush
                                    ? 'Sell an inventory product'
                                    : 'Existing inventory product',
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'new',
                              child: Text(
                                widget.isMtush
                                    ? 'Add a new product and sell'
                                    : 'Add a new product',
                              ),
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
                                    actualSellingPriceController.clear();
                                    sizeController.clear();
                                    colorController.clear();
                                    conditionController.clear();
                                    newProductCategory = 'mens_clothing';
                                    newProductGender = 'mens';
                                    newProductType = 'other';
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
                              'No available inventory products found. Add stock before recording a sale.',
                              style: TextStyle(color: Colors.grey),
                            )
                          else
                            productNameField(
                              label: 'Search inventory products',
                            ),
                          if (selectedProduct != null) ...[
                            const SizedBox(height: 12),
                            if (widget.isMtush) ...[
                              TextFormField(
                                controller: actualSellingPriceController,
                                enabled: !isSubmitting,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Agreed selling price (KSh)',
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
                              DropdownButtonFormField<String>(
                                initialValue: paymentMethod,
                                decoration: const InputDecoration(
                                  labelText: 'Payment method',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'cash',
                                    child: Text('Cash'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'mpesa',
                                    child: Text('M-Pesa'),
                                  ),
                                ],
                                onChanged: isSubmitting
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setDialogState(
                                            () => paymentMethod = value,
                                          );
                                        }
                                      },
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildSaleSummary(
                              unitPrice: unitPrice,
                              unitProfit: unitProfit,
                              quantity: quantity,
                              stockLabel:
                                  'Available stock: ${_availableQuantity(selectedProduct)}',
                            ),
                          ],
                        ] else ...[
                          productNameField(
                            label: 'Product name (search or add new)',
                          ),
                          const SizedBox(height: 12),
                          if (widget.isMtush) ...[
                            DropdownButtonFormField<String>(
                              initialValue: newProductCategory,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                              ),
                              items: _mtushCategories.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: isSubmitting
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setDialogState(() {
                                          newProductCategory = value;
                                        });
                                      }
                                    },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: newProductGender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                              ),
                              items: _mtushGenders.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: isSubmitting
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setDialogState(() {
                                          newProductGender = value;
                                        });
                                      }
                                    },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: newProductType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Product type',
                              ),
                              items: _mtushProductTypes.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: isSubmitting
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setDialogState(() {
                                          newProductType = value;
                                        });
                                      }
                                    },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: sizeController,
                              enabled: !isSubmitting,
                              decoration: const InputDecoration(
                                labelText: 'Size (optional)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: colorController,
                              enabled: !isSubmitting,
                              decoration: const InputDecoration(
                                labelText: 'Colour (optional)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: conditionController,
                              enabled: !isSubmitting,
                              decoration: const InputDecoration(
                                labelText: 'Condition (optional)',
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: costPriceController,
                            enabled: !isSubmitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: widget.isMtush
                                  ? 'Buying cost per piece (KSh)'
                                  : 'Cost Price (KSh)',
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
                            decoration: InputDecoration(
                              labelText: widget.isMtush
                                  ? 'Default selling price (KSh)'
                                  : 'Selling Price (KSh)',
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
                          if (widget.isMtush) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: actualSellingPriceController,
                              enabled: !isSubmitting,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Agreed price for this sale (KSh)',
                              ),
                              validator: (value) {
                                final amount = double.tryParse(
                                  value?.trim() ?? '',
                                );
                                if (amount == null ||
                                    !amount.isFinite ||
                                    amount < 0) {
                                  return 'Enter a valid agreed price.';
                                }
                                return null;
                              },
                              onChanged: (_) => setDialogState(() {
                                submissionError = null;
                              }),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: paymentMethod,
                              decoration: const InputDecoration(
                                labelText: 'Payment method',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'cash',
                                  child: Text('Cash'),
                                ),
                                DropdownMenuItem(
                                  value: 'mpesa',
                                  child: Text('M-Pesa'),
                                ),
                              ],
                              onChanged: isSubmitting
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setDialogState(
                                          () => paymentMethod = value,
                                        );
                                      }
                                    },
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: openingStockController,
                            enabled: !isSubmitting,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity to add to inventory',
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
                            unitProfit: unitProfit,
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
                                    _availableQuantity(selectedProduct)) {
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
                  style: widget.isMtush
                      ? ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                        )
                      : null,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.isMtush ? 'Complete sale' : 'Record Sale'),
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
    actualSellingPriceController.dispose();
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
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Text(
          widget.isMtush ? 'MTUSH PRODUCT SALES' : 'PRODUCT SALES',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
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
          : widget.isMtush
          ? _buildMtushSalesLayout()
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
        label: Text(widget.isMtush ? 'New sale' : 'Record Sale'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMtushSalesLayout() {
    final availableProducts = _availableProducts();
    final availableUnits = availableProducts.fold<int>(
      0,
      (total, product) => total + _availableQuantity(product),
    );

    return RefreshIndicator(
      onRefresh: () => fetchProductData(refresh: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sections = constraints.maxWidth >= 900
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.storefront_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mtush sales',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Choose an item, agree on a price, and record the sale.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _salesSummaryCard(
                            icon: Icons.checkroom_outlined,
                            label: 'Products ready to sell',
                            value: availableProducts.length.toString(),
                          ),
                          _salesSummaryCard(
                            icon: Icons.inventory_2_outlined,
                            label: 'Available pieces',
                            value: availableUnits.toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _productSearchController,
                        onChanged: (value) => setState(() {
                          _productSearchQuery = value.trim().toLowerCase();
                        }),
                        decoration: InputDecoration(
                          hintText: 'Search name, category, size or colour',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _productSearchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _productSearchController.clear();
                                    setState(() => _productSearchQuery = '');
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE5EF),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE5EF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      sections,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _salesSummaryCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2EAF2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF1565C0)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF60758A),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF17324D),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    final visibleProducts = widget.isMtush
        ? products.where(_matchesProductSearch).toList()
        : products;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isMtush ? 'Products to sell' : 'Inventory',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF17324D),
          ),
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          _buildEmptyState('No inventory products found.')
        else if (visibleProducts.isEmpty)
          _buildEmptyState('No products match your search.')
        else
          ...visibleProducts.map(_buildProductCard),
      ],
    );
  }

  bool _matchesProductSearch(dynamic product) {
    if (product is! Map) return false;
    if (_productSearchQuery.isEmpty) return true;
    final searchableValues = [
      product['name'],
      product['category']?.toString().replaceAll('_', ' '),
      product['gender'],
      product['productType']?.toString().replaceAll('_', ' '),
      product['size'],
      product['color'],
      product['condition'],
    ];
    return searchableValues.any(
      (value) =>
          value?.toString().toLowerCase().contains(_productSearchQuery) ??
          false,
    );
  }

  Widget _buildSalesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent sales',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF17324D),
          ),
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

    if (widget.isMtush) return _buildMtushProductCard(product);

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
          'Available: ${_availableQuantity(product)} • Stock: $quantity',
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

  Widget _buildMtushProductCard(Map<dynamic, dynamic> product) {
    final name = product['name']?.toString() ?? 'Unnamed product';
    final available = _availableQuantity(product);
    final reserved = _parseInteger(product['reservedQuantity']);

    final details = <String>[
      product['gender']?.toString() ?? '',
      product['productType']?.toString().replaceAll('_', ' ') ?? '',
      if (product['size']?.toString().trim().isNotEmpty == true)
        'Size ${product['size']}',
      if (product['color']?.toString().trim().isNotEmpty == true)
        product['color'].toString(),
      if (product['condition']?.toString().trim().isNotEmpty == true)
        product['condition'].toString(),
    ].where((detail) => detail.isNotEmpty).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2EAF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product information
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.checkroom_outlined,
                    color: Color(0xFF1565C0),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFF17324D),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (details.isNotEmpty)
                      Text(
                        details.join(' • '),
                        style: const TextStyle(
                          color: Color(0xFF60758A),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                Text(
                  _formatCurrency(product['sellingPrice']),
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Stock information and Sell button
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _stockBadge(
                  label: '$available available',
                  color: available > 0
                      ? const Color(0xFF1B7F5A)
                      : const Color(0xFFB54747),
                  background: available > 0
                      ? const Color(0xFFE9F7F0)
                      : const Color(0xFFFFEEEE),
                ),

                if (reserved > 0)
                  _stockBadge(
                    label: '$reserved reserved',
                    color: const Color(0xFF8A5A00),
                    background: const Color(0xFFFFF4D6),
                  ),

                OutlinedButton.icon(
                  onPressed: available > 0
                      ? () => showRecordSaleDialog(
                          initialItemId: _productId(product),
                        )
                      : null,
                  icon: const Icon(Icons.point_of_sale, size: 18),
                  label: const Text('Sell'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    side: const BorderSide(color: Color(0xFFB8D3F2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockBadge({
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
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

    final saleSubtitle = widget.isMtush
        ? '${sale['quantity'] ?? 0} piece(s) • '
              '${_formatCurrency(sale['sellingPrice'])} each • '
              '${sale['paymentMethod']?.toString().toUpperCase() ?? 'CASH'}'
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2EAF2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.receipt_long, color: Color(0xFF1565C0)),
        ),
        title: Text(
          productName,
          style: const TextStyle(
            color: Color(0xFF17324D),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: saleSubtitle == null ? null : Text(saleSubtitle),
        trailing: Text(
          widget.isMtush
              ? 'Total ${_formatCurrency(sale['totalAmount'])}'
              : 'Total profit: ${_formatCurrency(sale['profitAmount'])}',
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
    required double unitProfit,
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
            Text(
              '${widget.isMtush ? 'Agreed price' : 'Selling price'}: '
              '${_formatCurrency(unitPrice)}',
            ),
            const SizedBox(height: 4),
            Text('Profit per unit: ${_formatCurrency(unitProfit)}'),
            const SizedBox(height: 4),
            Text(stockLabel),
            const Divider(),
            Text(
              '${widget.isMtush ? 'Estimated sale profit' : 'Estimated total profit'}: '
              '${_formatCurrency(unitProfit * quantity)}',
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
      if (product is Map &&
          product['_id'] != null &&
          (!widget.isMtush || _availableQuantity(product) > 0)) {
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

  int _availableQuantity(Map<dynamic, dynamic> product) {
    final stock = _parseInteger(product['quantityInStock']);
    final reserved = _parseInteger(product['reservedQuantity']);
    return (stock - reserved).clamp(0, stock);
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
