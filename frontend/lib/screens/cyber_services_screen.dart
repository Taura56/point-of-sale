import 'package:flutter/material.dart';

import 'product_sales_screen.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../widgets/date_period_filter.dart';

class CyberServicesScreen extends StatefulWidget {
  const CyberServicesScreen({super.key});

  @override
  State<CyberServicesScreen> createState() => _CyberServicesScreenState();
}

class _CyberServicesScreenState extends State<CyberServicesScreen> {
  List<dynamic> services = [];
  List<dynamic> serviceEntries = [];
  bool isLoadingServiceEntries = true;
  bool serviceEntriesPermissionDenied = false;
  String? serviceEntriesError;
  List<dynamic> productSales = [];
  bool isLoadingProductSales = true;
  bool productSalesPermissionDenied = false;
  String? productSalesError;

  bool isLoading = true;
  String? errorMessage;
  DatePeriodSelection _dateSelection = DatePeriodSelection(
    period: DatePeriod.day,
    anchorDate: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    fetchServices();
    fetchServiceEntries();
    fetchProductSales();
  }

  Future<void> fetchServices() async {
    if (!mounted) return;

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();

      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      final response = await ApiService.get(
        '/businesses/$businessId/services',
        token: token,
      );

      if (!mounted) return;

      setState(() {
        services = response['data'] ?? [];
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = _formatError(error);
        isLoading = false;
      });
    }
  }

  Future<void> fetchProductSales() async {
    if (!mounted) return;

    try {
      setState(() {
        isLoadingProductSales = true;
        productSalesPermissionDenied = false;
        productSalesError = null;
      });

      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();

      if (token == null || businessId == null) {
        throw Exception('Please log in again.');
      }

      final response = await ApiService.get(
        '/businesses/$businessId/product-sales',
        token: token,
      );
      final sales = response['sales'];
      if (sales is! List) {
        throw Exception('Unable to load product sales.');
      }

      if (!mounted) return;

      setState(() {
        productSales = List<dynamic>.from(sales);
      });
    } catch (error) {
      if (!mounted) return;

      final forbidden =
          error is ApiException &&
          error.statusCode == 403 &&
          error.message == 'You do not have permission to perform this action';
      setState(() {
        productSalesPermissionDenied = forbidden;
        productSalesError = forbidden
            ? 'Product sales are available only to owners and managers.'
            : _formatError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingProductSales = false;
        });
      }
    }
  }

  Future<void> fetchServiceEntries() async {
    if (!mounted) return;

    try {
      setState(() {
        isLoadingServiceEntries = true;
        serviceEntriesPermissionDenied = false;
        serviceEntriesError = null;
      });

      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();

      if (token == null || businessId == null) {
        throw Exception('Please log in again.');
      }

      final response = await ApiService.get(
        '/businesses/$businessId/service-entries',
        token: token,
      );
      final entries = response['entries'];
      if (entries is! List) {
        throw Exception('Unable to load saved service details.');
      }

      if (!mounted) return;
      setState(() {
        serviceEntries = List<dynamic>.from(entries);
      });
    } catch (error) {
      if (!mounted) return;

      final forbidden =
          error is ApiException &&
          error.statusCode == 403 &&
          error.message == 'You do not have permission to perform this action';
      setState(() {
        serviceEntriesPermissionDenied = forbidden;
        serviceEntriesError = forbidden
            ? 'Saved service details are available only to owners and managers.'
            : _formatError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingServiceEntries = false;
        });
      }
    }
  }

  void showAddServiceDialog() {
    final nameController = TextEditingController();
    final feeController = TextEditingController();
    final quantityController = TextEditingController();
    final nameFocusNode = FocusNode();
    var isSaving = false;
    String? selectedServiceId;
    String? formError;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContentContext, setDialogState) {
            Map? findMatchingService(String name) {
              final normalizedName = name.trim().toLowerCase();
              if (normalizedName.isEmpty) return null;

              for (final service in services) {
                if (service is Map &&
                    service['name']?.toString().trim().toLowerCase() ==
                        normalizedName) {
                  return service;
                }
              }
              return null;
            }

            Future<void> saveService() async {
              final name = nameController.text.trim();
              final fee = double.tryParse(feeController.text.trim());
              final quantity = int.tryParse(quantityController.text.trim());

              if (name.isEmpty ||
                  fee == null ||
                  !fee.isFinite ||
                  fee < 0 ||
                  quantity == null ||
                  quantity <= 0 ||
                  !(fee * quantity).isFinite) {
                setDialogState(() {
                  formError = 'Enter a service name, a valid unit price, and a quantity greater than zero.';
                });
                return;
              }

              setDialogState(() {
                isSaving = true;
                formError = null;
              });

              try {
                final token = await TokenService.getToken();
                final businessId = await TokenService.getBusinessId();

                if (token == null || businessId == null) {
                  throw Exception('Please log in again.');
                }

                final body = <String, dynamic>{
                  'name': name,
                  'serviceFee': fee,
                  'quantity': quantity,
                  'totalPrice': fee * quantity,
                };
                if (selectedServiceId != null) {
                  body['serviceId'] = selectedServiceId;
                }
                await ApiService.post(
                  '/businesses/$businessId/service-entries',
                  body,
                  token: token,
                );

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Service details saved. Total: KSh ${(fee * quantity).toStringAsFixed(2)}.',
                    ),
                  ),
                );
                await Future.wait([fetchServices(), fetchServiceEntries()]);
              } catch (error) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  isSaving = false;
                  formError = _formatError(error);
                });
              }
            }

            final dialogWidth =
                MediaQuery.sizeOf(dialogContentContext).width * 0.8;

            return AlertDialog(
              title: const Text('Add a Service'),
              content: SizedBox(
                width: dialogWidth > 420 ? 420 : dialogWidth,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RawAutocomplete<String>(
                        textEditingController: nameController,
                        focusNode: nameFocusNode,
                        displayStringForOption: (option) => option,
                        optionsBuilder: (textEditingValue) {
                          final query = textEditingValue.text
                              .trim()
                              .toLowerCase();
                          if (query.isEmpty) {
                            return const Iterable<String>.empty();
                          }

                          return services
                              .whereType<Map>()
                              .map((service) => service['name']?.toString())
                              .whereType<String>()
                              .where(
                                (name) => name.toLowerCase().contains(query),
                              );
                        },
                        onSelected: (name) {
                          final service = findMatchingService(name);
                          if (service == null) return;
                          selectedServiceId = service['_id']?.toString();
                          feeController.text = service['serviceFee'].toString();
                          setDialogState(() {
                            formError = null;
                          });
                        },
                        fieldViewBuilder:
                            (
                              _,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                enabled: !isSaving,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Service name',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (name) {
                                  final service = findMatchingService(name);
                                  setDialogState(() {
                                    if (service != null) {
                                      selectedServiceId = service['_id']
                                          ?.toString();
                                      feeController.text = service['serviceFee']
                                          .toString();
                                    } else {
                                      if (selectedServiceId != null) {
                                        feeController.clear();
                                      }
                                      selectedServiceId = null;
                                    }
                                    formError = null;
                                  });
                                },
                                onSubmitted: (_) => onFieldSubmitted(),
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
                                  maxHeight: 200,
                                  maxWidth: 420,
                                ),
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  children: options
                                      .map(
                                        (option) => ListTile(
                                          dense: true,
                                          title: Text(option),
                                          onTap: () => onSelected(option),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: feeController,
                        enabled: !isSaving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Unit price (KSh)',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: quantityController,
                        enabled: !isSaving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Total price (KSh)',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          'KSh ${((double.tryParse(feeController.text.trim()) ?? 0) * (int.tryParse(quantityController.text.trim()) ?? 0)).toStringAsFixed(2)}',
                        ),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          formError!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : saveService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Service'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      feeController.dispose();
      quantityController.dispose();
      nameFocusNode.dispose();
    });
  }

  String _formatError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Widget _buildServicesSection() {
    final visibleEntries = _dateSelection.filterEntries(serviceEntries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Cyber Services',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 20),
            Flexible(
              child: Text(
                '${_dateSelection.totalLabel}: ${isLoadingServiceEntries || serviceEntriesError != null ? '—' : _formatCurrency(_dateSelection.totalFor(serviceEntries, 'totalPrice'))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoadingServiceEntries)
          const Center(child: CircularProgressIndicator())
        else if (serviceEntriesError != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                serviceEntriesError!,
                style: TextStyle(
                  color: serviceEntriesPermissionDenied
                      ? Colors.grey.shade700
                      : Colors.red,
                ),
              ),
              if (!serviceEntriesPermissionDenied) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: fetchServiceEntries,
                  child: const Text('Retry'),
                ),
              ],
            ],
          )
        else if (visibleEntries.isEmpty)
          const Text('No service entries for this period.')
        else
          ...visibleEntries.map(_buildServiceEntryCard),
      ],
    );
  }

  Widget _buildServiceEntryCard(dynamic entry) {
    if (entry is! Map) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.computer, color: Color(0xFF1565C0)),
        title: Text(
          entry['serviceName']?.toString() ?? 'Unnamed service',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Text(
          'Total: ${_formatCurrency(entry['totalPrice'])}',
          style: const TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSalesSection() {
    final visibleSales = _dateSelection.filterEntries(productSales);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Product Sales',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 20),
            Flexible(
              child: Text(
                '${_dateSelection.totalLabel}: ${isLoadingProductSales || productSalesError != null ? '—' : _formatCurrency(_dateSelection.totalFor(productSales, 'totalAmount'))}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoadingProductSales)
          const Center(child: CircularProgressIndicator())
        else if (productSalesError != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productSalesError!,
                style: TextStyle(
                  color: productSalesPermissionDenied
                      ? Colors.grey.shade700
                      : Colors.red,
                ),
              ),
              if (!productSalesPermissionDenied) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: fetchProductSales,
                  child: const Text('Retry'),
                ),
              ],
            ],
          )
        else if (visibleSales.isEmpty)
          const Text('No product sales for this period.')
        else
          ...visibleSales.map(_buildProductSaleCard),
      ],
    );
  }

  Widget _buildProductSaleCard(dynamic sale) {
    if (sale is! Map) return const SizedBox.shrink();

    final item = sale['item'];
    final productName =
        sale['productName']?.toString() ??
        (item is Map ? item['name']?.toString() : null) ??
        'Unknown product';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
          style: const TextStyle(
            color: Color(0xFF1565C0),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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
          'CYBER SERVICES AND SALES',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Make a Sale',
                      icon: Icons.point_of_sale,
                      isCompact: isCompact,
                      onPressed: () async {
                        await showDialog<void>(
                          context: context,
                          barrierColor: Colors.transparent,
                          barrierDismissible: false,
                          builder: (_) =>
                              const ProductSalesScreen(openSaleOnOpen: true),
                        );
                        if (mounted) await fetchProductSales();
                      },
                    ),
                  ),
                  SizedBox(width: isCompact ? 12 : 20),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Add a Service',
                      icon: Icons.add,
                      isCompact: isCompact,
                      onPressed: showAddServiceDialog,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  fetchServices(),
                  fetchServiceEntries(),
                  fetchProductSales(),
                ]);
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sections = constraints.maxWidth >= 900
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildSalesSection()),
                            const SizedBox(width: 24),
                            Expanded(child: _buildServicesSection()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSalesSection(),
                            const SizedBox(height: 24),
                            _buildServicesSection(),
                          ],
                        );
                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DatePeriodFilterBar(
                        selection: _dateSelection,
                        onChanged: (selection) {
                          setState(() {
                            _dateSelection = selection;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      sections,
                    ],
                  );

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1300),
                          child: SizedBox(
                            width: double.infinity,
                            child: content,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isCompact,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isCompact ? 18 : 20),
            SizedBox(width: isCompact ? 4 : 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: isCompact ? 12 : 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
