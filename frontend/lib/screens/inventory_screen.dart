import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/token_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.isMtush = false});

  final bool isMtush;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const Map<String, String> _categories = {
    'phone_accessory': 'Phone Accessory',
    'phone_part': 'Phone Part',
    'electronics': 'Electronics',
    'other': 'Other',
  };
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

  List<dynamic> products = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchInventoryItems();
  }

  Future<void> fetchInventoryItems({bool refresh = false}) async {
    if (!mounted) return;

    setState(() {
      if (!refresh) isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();

      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      final response = await ApiService.get(
        '/businesses/$businessId/inventory',
        token: token,
      );
      final items = response is Map ? response['items'] : null;
      if (items is! List) {
        throw Exception('Unable to load inventory products.');
      }

      if (!mounted) return;
      setState(() {
        products = List<dynamic>.from(items);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error is ApiException
            ? error.message
            : error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(labelText: label);
  }

  Future<void> _showItemDialog({Map<dynamic, dynamic>? product}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: product?['name']?.toString() ?? '',
    );
    final skuController = TextEditingController(
      text: product?['sku']?.toString() ?? '',
    );
    final costPriceController = TextEditingController(
      text: product?['costPrice']?.toString() ?? '',
    );
    final sellingPriceController = TextEditingController(
      text: product?['sellingPrice']?.toString() ?? '',
    );
    final quantityController = TextEditingController(
      text: product?['quantityInStock']?.toString() ?? '0',
    );
    final reorderLevelController = TextEditingController(
      text: product?['reorderLevel']?.toString() ?? '5',
    );
    final sizeController = TextEditingController(
      text: product?['size']?.toString() ?? '',
    );
    final colorController = TextEditingController(
      text: product?['color']?.toString() ?? '',
    );
    final conditionController = TextEditingController(
      text: product?['condition']?.toString() ?? '',
    );
    final itemId = product?['_id']?.toString() ?? product?['id']?.toString();
    final categories = widget.isMtush ? _mtushCategories : _categories;
    var selectedCategory =
        categories.containsKey(product?['category']?.toString())
        ? product!['category'].toString()
        : 'other';
    var selectedGender =
        _mtushGenders.containsKey(product?['gender']?.toString())
        ? product!['gender'].toString()
        : 'other';
    var selectedProductType =
        _mtushProductTypes.containsKey(product?['productType']?.toString())
        ? product!['productType'].toString()
        : 'other';
    var isSaving = false;
    String? formError;

    String? validatePrice(String? value, String label) {
      final amount = double.tryParse(value?.trim() ?? '');
      if (amount == null || !amount.isFinite || amount < 0) {
        return 'Enter a valid non-negative $label.';
      }
      return null;
    }

    String? validateWholeNumber(String? value, String label) {
      final number = int.tryParse(value?.trim() ?? '');
      if (number == null || number < 0) {
        return 'Enter a valid non-negative whole $label.';
      }
      return null;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> saveItem() async {
            if (formKey.currentState?.validate() != true) return;

            final messenger = ScaffoldMessenger.of(context);
            setDialogState(() {
              isSaving = true;
              formError = null;
            });

            try {
              final token = await TokenService.getToken();
              final businessId = await TokenService.getBusinessId();
              if (token == null || businessId == null) {
                throw Exception(
                  'Login information not found. Please log in again.',
                );
              }
              if (product != null && (itemId == null || itemId.isEmpty)) {
                throw Exception('Inventory item ID not found.');
              }

              final itemData = {
                'name': nameController.text.trim(),
                'category': selectedCategory,
                'sku': skuController.text.trim(),
                'costPrice': double.parse(costPriceController.text.trim()),
                'sellingPrice': double.parse(
                  sellingPriceController.text.trim(),
                ),
                'quantityInStock': int.parse(quantityController.text.trim()),
                'reorderLevel': int.parse(reorderLevelController.text.trim()),
                if (widget.isMtush) ...{
                  'gender': selectedGender,
                  'productType': selectedProductType,
                  'size': sizeController.text.trim(),
                  'color': colorController.text.trim(),
                  'condition': conditionController.text.trim(),
                },
              };

              if (product == null) {
                await ApiService.post(
                  '/businesses/$businessId/inventory',
                  itemData,
                  token: token,
                );
              } else {
                await ApiService.patch(
                  '/businesses/$businessId/inventory/$itemId',
                  itemData,
                  token: token,
                );
              }

              if (!mounted || !dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    product == null
                        ? 'Inventory item added.'
                        : 'Inventory item updated.',
                  ),
                ),
              );
              await fetchInventoryItems(refresh: true);
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                formError = error is ApiException
                    ? error.message
                    : error.toString().replaceFirst('Exception: ', '');
              });
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() {
                  isSaving = false;
                });
              }
            }
          }

          return AlertDialog(
            title: Text(
              product == null ? 'Add Inventory Item' : 'Edit Inventory Item',
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        enabled: !isSaving,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDecoration('Product Name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a product name.'
                            : null,
                        onChanged: (_) => setDialogState(() {
                          formError = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        decoration: _inputDecoration('Category'),
                        items: categories.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() {
                                    selectedCategory = value;
                                    formError = null;
                                  });
                                }
                              },
                      ),
                      if (widget.isMtush) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedGender,
                          isExpanded: true,
                          decoration: _inputDecoration('Gender'),
                          items: _mtushGenders.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(
                                      () => selectedGender = value,
                                    );
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedProductType,
                          isExpanded: true,
                          decoration: _inputDecoration('Product type'),
                          items: _mtushProductTypes.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setDialogState(
                                      () => selectedProductType = value,
                                    );
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: sizeController,
                          enabled: !isSaving,
                          decoration: _inputDecoration('Size (optional)'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: colorController,
                          enabled: !isSaving,
                          decoration: _inputDecoration('Colour (optional)'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: conditionController,
                          enabled: !isSaving,
                          decoration: _inputDecoration('Condition (optional)'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: skuController,
                        enabled: !isSaving,
                        decoration: _inputDecoration('SKU (optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: costPriceController,
                        enabled: !isSaving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration('Cost Price (KSh)'),
                        validator: (value) =>
                            validatePrice(value, 'cost price'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: sellingPriceController,
                        enabled: !isSaving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration('Selling Price (KSh)'),
                        validator: (value) =>
                            validatePrice(value, 'selling price'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: quantityController,
                        enabled: !isSaving,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          widget.isMtush && product == null
                              ? 'Opening stock quantity'
                              : 'Quantity in Stock',
                        ).copyWith(
                          helperText: widget.isMtush
                              ? 'Changes here update inventory stock.'
                              : null,
                        ),
                        validator: (value) =>
                            validateWholeNumber(value, 'stock quantity'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: reorderLevelController,
                        enabled: !isSaving,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Low Stock Alert Level'),
                        validator: (value) =>
                            validateWholeNumber(value, 'alert level'),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          formError!,
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
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : saveItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(product == null ? 'Add Item' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      nameController.dispose();
      skuController.dispose();
      costPriceController.dispose();
      sellingPriceController.dispose();
      quantityController.dispose();
      reorderLevelController.dispose();
      sizeController.dispose();
      colorController.dispose();
      conditionController.dispose();
    });
  }

  Future<void> _confirmDeleteItem(Map<dynamic, dynamic> product) async {
    final itemId = product['_id']?.toString() ?? product['id']?.toString();
    if (itemId == null || itemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory item ID not found.')),
      );
      return;
    }

    final itemName = product['name']?.toString() ?? 'this item';
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete inventory item?'),
        content: Text(
          '$itemName will be removed from active inventory. Existing sales '
          'and stock history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    try {
      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();
      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      await ApiService.delete(
        '/businesses/$businessId/inventory/$itemId',
        token: token,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Inventory item deleted.')));
      await fetchInventoryItems(refresh: true);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildEmptyState() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3F2FD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(
                Icons.inventory_2,
                size: 32,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No inventory items found.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Inventory items will appear here when available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3F2FD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: fetchInventoryItems,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    if (product is! Map) return const SizedBox.shrink();

    final name = product['name']?.toString().trim();
    final category = product['category']?.toString().replaceAll('_', ' ');
    final quantity = product['quantityInStock']?.toString() ?? '—';
    final reserved = widget.isMtush
        ? _parseQuantity(product['reservedQuantity'])
        : 0;
    final available = widget.isMtush
        ? (_parseQuantity(product['quantityInStock']) - reserved).clamp(
            0,
            1 << 30,
          )
        : null;
    final productDetails = <String>[
      if (category != null && category.isNotEmpty) category,
      if (widget.isMtush && product['gender'] != null)
        product['gender'].toString(),
      if (widget.isMtush && product['productType'] != null)
        product['productType'].toString().replaceAll('_', ' '),
      if (widget.isMtush && product['size']?.toString().isNotEmpty == true)
        'Size ${product['size']}',
      if (widget.isMtush && product['color']?.toString().isNotEmpty == true)
        product['color'].toString(),
      if (widget.isMtush && product['condition']?.toString().isNotEmpty == true)
        product['condition'].toString(),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3F2FD)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE3F2FD),
          child: Icon(Icons.inventory_2, color: Color(0xFF1565C0)),
        ),
        title: Text(
          name?.isNotEmpty == true ? name! : 'Unnamed product',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${productDetails.isEmpty ? 'Product' : productDetails.join(' • ')}\n'
          'Stock: $quantity'
          '${widget.isMtush ? ' • Available: $available • Reserved: $reserved' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatCurrency(product['sellingPrice']),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Manage ${name?.isNotEmpty == true ? name : 'item'}',
              onSelected: (action) {
                final item = Map<dynamic, dynamic>.from(product);
                if (action == 'edit') {
                  _showItemDialog(product: item);
                } else if (action == 'delete') {
                  _confirmDeleteItem(item);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _parseQuantity(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Text(
          'INVENTORY',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showItemDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => fetchInventoryItems(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Inventory',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (errorMessage != null)
                      _buildErrorState()
                    else if (products.isEmpty)
                      _buildEmptyState()
                    else
                      ...products.map(_buildProductCard),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
