import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/token_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  static const List<String> _categories = [
    'rent',
    'electricity',
    'internet',
    'transport',
    'supplies',
    'maintenance',
    'salaries',
    'other',
  ];

  static const List<String> _paymentMethods = [
    'cash',
    'mpesa',
    'bank',
    'other',
  ];

  List<dynamic> expenses = [];
  bool isLoading = true;
  bool isRefreshing = false;
  bool isPermissionDenied = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchExpenses();
  }

  Future<void> fetchExpenses({bool refresh = false}) async {
    setState(() {
      if (refresh) {
        isRefreshing = true;
      } else {
        isLoading = true;
      }
      isPermissionDenied = false;
      errorMessage = null;
    });

    try {
      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();

      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      final response = await ApiService.get(
        '/businesses/$businessId/expenses',
        token: token,
      );
      final expenseList = response['expenses'];

      if (expenseList is! List) {
        throw Exception('Unable to load expenses.');
      }

      if (!mounted) return;

      setState(() {
        expenses = List<dynamic>.from(expenseList);
      });
    } catch (error) {
      if (!mounted) return;

      final forbidden =
          error is ApiException &&
          error.statusCode == 403 &&
          error.message == 'You do not have permission to perform this action';
      setState(() {
        isPermissionDenied = forbidden;
        errorMessage = forbidden
            ? 'Expense history is available only to owners and managers. '
                  'You may still add an expense if your role allows it.'
            : error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
      }
    }
  }

  Future<void> showAddExpenseDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    String selectedCategory = 'other';
    String selectedPaymentMethod = 'cash';
    DateTime selectedDate = DateTime.now();
    bool isSubmitting = false;
    String? submissionError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContentContext, setDialogState) {
            Future<void> submitExpense() async {
              if (!formKey.currentState!.validate()) return;

              final amount = double.parse(amountController.text.trim());
              final request = <String, dynamic>{
                'title': titleController.text.trim(),
                'category': selectedCategory,
                'amount': amount,
                'paymentMethod': selectedPaymentMethod,
                'expenseDate': selectedDate.toIso8601String(),
              };

              final description = descriptionController.text.trim();
              if (description.isNotEmpty) {
                request['description'] = description;
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

                await ApiService.post(
                  '/businesses/$businessId/expenses',
                  request,
                  token: token,
                );

                if (!dialogContentContext.mounted) return;
                Navigator.pop(dialogContentContext);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Expense recorded successfully.'),
                  ),
                );
                await fetchExpenses(refresh: true);
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
              title: const Text('Add Expense'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: titleController,
                          enabled: !isSubmitting,
                          decoration: const InputDecoration(
                            labelText: 'Expense Title',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter an expense title.'
                              : null,
                          onChanged: (_) => setDialogState(() {
                            submissionError = null;
                          }),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: amountController,
                          enabled: !isSubmitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount (KSh)',
                          ),
                          validator: (value) {
                            final amount = double.tryParse(value?.trim() ?? '');
                            if (amount == null ||
                                !amount.isFinite ||
                                amount <= 0) {
                              return 'Enter an amount greater than zero.';
                            }
                            return null;
                          },
                          onChanged: (_) => setDialogState(() {
                            submissionError = null;
                          }),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: _categories
                              .map(
                                (category) => DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(_formatLabel(category)),
                                ),
                              )
                              .toList(),
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() {
                                    selectedCategory = value;
                                    submissionError = null;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedPaymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                          ),
                          items: _paymentMethods
                              .map(
                                (method) => DropdownMenuItem<String>(
                                  value: method,
                                  child: Text(_formatLabel(method)),
                                ),
                              )
                              .toList(),
                          onChanged: isSubmitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() {
                                    selectedPaymentMethod = value;
                                    submissionError = null;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final pickedDate = await showDatePicker(
                                    context: dialogContentContext,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (pickedDate == null) return;

                                  setDialogState(() {
                                    selectedDate = pickedDate;
                                    submissionError = null;
                                  });
                                },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            'Expense Date: ${_formatDate(selectedDate)}',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          enabled: !isSubmitting,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description (Optional)',
                            alignLabelWithHint: true,
                          ),
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
                  onPressed: isSubmitting ? null : submitExpense,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Expense'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    amountController.dispose();
    descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
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
              tooltip: 'Refresh expenses',
              onPressed: isLoading ? null : () => fetchExpenses(refresh: true),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: () => fetchExpenses(refresh: true),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth >= 900 ? 1000 : 650,
                          ),
                          child: expenses.isEmpty
                              ? _buildEmptyState()
                              : Column(
                                  children: expenses
                                      .map(_buildExpenseCard)
                                      .toList(),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : showAddExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
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
            if (!isPermissionDenied)
              ElevatedButton(
                onPressed: fetchExpenses,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            'No expenses recorded yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCard(dynamic expense) {
    if (expense is! Map) return const SizedBox.shrink();

    final dateValue = expense['expenseDate'];
    final expenseDate = dateValue == null
        ? null
        : DateTime.tryParse(dateValue.toString())?.toLocal();
    final category = expense['category']?.toString() ?? 'other';
    final paymentMethod = expense['paymentMethod']?.toString();
    final description = expense['description']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE3F2FD),
          child: Icon(Icons.receipt_long, color: Color(0xFF1565C0)),
        ),
        title: Text(
          expense['title']?.toString() ?? 'Untitled Expense',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              if (description.isNotEmpty) description,
              'Category: ${_formatLabel(category)}',
              if (paymentMethod != null && paymentMethod.isNotEmpty)
                'Payment: ${_formatLabel(paymentMethod)}',
              _formatDate(expenseDate),
            ].join('\n'),
          ),
        ),
        trailing: Text(
          _formatCurrency(expense['amount']),
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
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

  String _formatLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date unavailable';

    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
