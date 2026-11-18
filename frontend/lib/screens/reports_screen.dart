import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/token_service.dart';
import '../widgets/date_period_filter.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DatePeriodSelection _dateSelection = DatePeriodSelection(
    period: DatePeriod.day,
    anchorDate: DateTime.now(),
  );

  List<dynamic> transactions = [];
  List<dynamic> productSales = [];
  List<dynamic> serviceEntries = [];
  List<dynamic> expenses = [];
  List<dynamic> repairJobs = [];
  List<dynamic> inventoryItems = [];
  Map<String, String> sectionErrors = {};
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  String _formatError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> fetchReports({bool refresh = false}) async {
    if (!mounted) return;

    setState(() {
      if (!refresh) isLoading = true;
      errorMessage = null;
      sectionErrors = {};
    });

    try {
      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();
      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      final loadedSectionErrors = <String, String>{};
      Future<List<dynamic>> loadSection(
        String section,
        String endpoint,
        String responseKey,
      ) async {
        try {
          final response = await ApiService.get(
            '/businesses/$businessId/$endpoint',
            token: token,
          );
          final values = response is Map ? response[responseKey] : null;
          if (values is! List) {
            throw Exception('Unable to load $section report data.');
          }
          return List<dynamic>.from(values);
        } catch (error) {
          loadedSectionErrors[section] = _formatError(error);
          return [];
        }
      }

      final results = await Future.wait<List<dynamic>>([
        loadSection('transactions', 'transactions', 'data'),
        loadSection('product sales', 'product-sales', 'sales'),
        loadSection('cyber services', 'service-entries', 'entries'),
        loadSection('expenses', 'expenses', 'expenses'),
        loadSection('repairs', 'repairs', 'data'),
        loadSection('inventory', 'inventory', 'items'),
      ]);

      if (!mounted) return;
      setState(() {
        transactions = results[0];
        productSales = results[1];
        serviceEntries = results[2];
        expenses = results[3];
        repairJobs = results[4];
        inventoryItems = results[5];
        sectionErrors = loadedSectionErrors;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = _formatError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<dynamic> _paidRecords(List<dynamic> records) {
    return _dateSelection.filterEntries(records).where((record) {
      if (record is! Map) return false;
      final status = record['paymentStatus']?.toString();
      return status == null || status == 'paid';
    }).toList();
  }

  List<dynamic> get _filteredServiceEntries =>
      _dateSelection.filterEntries(serviceEntries);

  List<dynamic> get _filteredExpenses =>
      _dateSelection.filterEntries(expenses, dateField: 'expenseDate');

  List<dynamic> get _filteredRepairJobs =>
      _dateSelection.filterEntries(repairJobs);

  List<dynamic> get _paidTransactions => _paidRecords(transactions);

  List<dynamic> get _paidProductSales => _paidRecords(productSales);

  double _amount(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    return parsed != null && parsed.isFinite ? parsed : 0;
  }

  double _sum(Iterable<dynamic> records, String amountField) {
    var total = 0.0;
    for (final record in records) {
      if (record is Map) total += _amount(record[amountField]);
    }
    return total;
  }

  double _salesAmount(dynamic record) {
    if (record is! Map) return 0;
    return _amount(
      record.containsKey('productName')
          ? record['profitAmount']
          : record['totalAmount'],
    );
  }

  String _formatCurrency(num value) {
    final amount = value.toDouble();
    final formattedAmount = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return 'KSh $formattedAmount';
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataError(String section) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sectionErrors[section]!,
            style: const TextStyle(color: Colors.red),
          ),
          TextButton(
            onPressed: () => fetchReports(refresh: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPartialDataNotice() {
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF8D6E00)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Some report sources could not be loaded. Totals exclude '
                'unavailable data.',
                style: TextStyle(color: Colors.brown.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3F2FD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE3F2FD),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.blueGrey.shade700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final income =
        _sum(_paidTransactions, 'totalAmount') +
        _sum(_paidProductSales, 'profitAmount') +
        _sum(_filteredServiceEntries, 'totalPrice') +
        _sum(_filteredRepairJobs, 'amountPaid');
    final expenseTotal = _dateSelection.totalFor(
      expenses,
      'amount',
      dateField: 'expenseDate',
    );
    final incomeIncomplete = [
      'transactions',
      'product sales',
      'cyber services',
      'repairs',
    ].any(sectionErrors.containsKey);
    final expenseIncomplete = sectionErrors.containsKey('expenses');
    final balanceIncomplete = incomeIncomplete || expenseIncomplete;
    final width = (MediaQuery.sizeOf(context).width - 32)
        .clamp(0.0, 1000.0)
        .toDouble();
    final columns = width >= 900
        ? 3
        : width >= 600
        ? 2
        : 1;
    final cardWidth = columns == 1
        ? width
        : (width - (columns - 1) * 12) / columns;

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        SizedBox(
          width: cardWidth,
          child: _buildMetricCard(
            title: incomeIncomplete ? 'Total Income (partial)' : 'Total Income',
            value: _formatCurrency(income),
            icon: Icons.trending_up,
            color: const Color(0xFF1565C0),
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _buildMetricCard(
            title: expenseIncomplete ? 'Expenses (partial)' : 'Expenses',
            value: _formatCurrency(expenseTotal),
            icon: Icons.money_off,
            color: Colors.deepOrange,
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _buildMetricCard(
            title: balanceIncomplete
                ? 'After Expenses (partial)'
                : 'After Expenses',
            value: _formatCurrency(income - expenseTotal),
            icon: Icons.account_balance_wallet,
            color: const Color(0xFF2E7D32),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      child: Text(
        'After expenses is an estimate; other operating costs may not be fully accounted for.',
        style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12),
      ),
    );
  }

  Widget _buildReportCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3F2FD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1565C0),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24, color: Color(0xFFE3F2FD)),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow({
    required String title,
    required String section,
    required List<dynamic> records,
    required String amountField,
    String? countLabel,
    double? amountOverride,
  }) {
    if (sectionErrors.containsKey(section)) {
      return _buildDataError(section);
    }

    final detail = countLabel == null
        ? '${records.length} records'
        : '${records.length} $countLabel';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatCurrency(amountOverride ?? _sum(records, amountField)),
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeBreakdown() {
    return _buildReportCard('Collection Sources', [
      _buildFinancialRow(
        title: 'Customer transactions',
        section: 'transactions',
        records: _paidTransactions,
        amountField: 'totalAmount',
        countLabel: 'paid',
      ),
      _buildFinancialRow(
        title: 'Product sales profit',
        section: 'product sales',
        records: _paidProductSales,
        amountField: 'profitAmount',
        countLabel: 'paid',
      ),
      _buildFinancialRow(
        title: 'Cyber services',
        section: 'cyber services',
        records: _filteredServiceEntries,
        amountField: 'totalPrice',
        countLabel: 'entries',
      ),
      _buildFinancialRow(
        title: 'Repair payments received',
        section: 'repairs',
        records: _filteredRepairJobs,
        amountField: 'amountPaid',
        countLabel: 'jobs',
      ),
    ]);
  }

  Map<String, double> _groupTotals(
    Iterable<dynamic> records,
    String labelField,
    String amountField, {
    String? fallbackField,
  }) {
    final totals = <String, double>{};
    for (final record in records) {
      if (record is! Map) continue;
      final fallback = fallbackField == null
          ? null
          : record[fallbackField]?.toString();
      final label = record[labelField]?.toString().trim();
      final name = label?.isNotEmpty == true
          ? label!
          : fallback?.isNotEmpty == true
          ? fallback!
          : 'Other';
      totals.update(
        name,
        (total) => total + _amount(record[amountField]),
        ifAbsent: () => _amount(record[amountField]),
      );
    }
    return totals;
  }

  Widget _buildRankedCard({
    required String title,
    required String section,
    required List<dynamic> records,
    required String labelField,
    required String amountField,
    String? fallbackField,
  }) {
    if (sectionErrors.containsKey(section)) {
      return _buildReportCard(title, [_buildDataError(section)]);
    }

    final totals =
        _groupTotals(
            records,
            labelField,
            amountField,
            fallbackField: fallbackField,
          ).entries.toList()
          ..sort((left, right) => right.value.compareTo(left.value));

    if (totals.isEmpty) {
      return _buildReportCard(title, [
        const Text('No records for this period.'),
      ]);
    }

    final topValue = totals.first.value;
    return _buildReportCard(
      title,
      totals.take(5).map((entry) {
        final progress = topValue == 0 ? 0.0 : entry.value / topValue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatCurrency(entry.value),
                    style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                color: const Color(0xFF1565C0),
                backgroundColor: const Color(0xFFE3F2FD),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpenseBreakdown() {
    if (sectionErrors.containsKey('expenses')) {
      return _buildReportCard('Expenses by Category', [
        _buildDataError('expenses'),
      ]);
    }

    final totals =
        _groupTotals(
            _filteredExpenses,
            'category',
            'amount',
            fallbackField: 'title',
          ).entries.toList()
          ..sort((left, right) => right.value.compareTo(left.value));

    if (totals.isEmpty) {
      return _buildReportCard('Expenses by Category', [
        const Text('No expenses for this period.'),
      ]);
    }

    final total = totals.fold<double>(0, (sum, entry) => sum + entry.value);
    return _buildReportCard(
      'Expenses by Category',
      totals.map((entry) {
        final share = total == 0 ? 0.0 : entry.value / total;
        final label = entry.key
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(
                    _formatCurrency(entry.value),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: share,
                color: Colors.deepOrange,
                backgroundColor: const Color(0xFFFFE0B2),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentMethods() {
    if (sectionErrors.containsKey('transactions') ||
        sectionErrors.containsKey('product sales')) {
      return _buildReportCard('Sales by Payment Method', [
        if (sectionErrors.containsKey('transactions'))
          _buildDataError('transactions'),
        if (sectionErrors.containsKey('product sales'))
          _buildDataError('product sales'),
      ]);
    }

    final totals = <String, double>{};
    for (final record in [..._paidTransactions, ..._paidProductSales]) {
      if (record is! Map) continue;
      final method = record['paymentMethod']?.toString() ?? 'other';
      totals.update(
        method,
        (total) => total + _salesAmount(record),
        ifAbsent: () => _salesAmount(record),
      );
    }

    if (totals.isEmpty) {
      return _buildReportCard('Sales by Payment Method', [
        const Text('No paid sales for this period.'),
      ]);
    }

    final entries = totals.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return _buildReportCard(
      'Sales by Payment Method',
      entries.map((entry) {
        final method = entry.key
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
        return _buildFinancialRow(
          title: method,
          section: 'payment methods',
          records: [
            for (final record in [..._paidTransactions, ..._paidProductSales])
              if (record is Map &&
                  (record['paymentMethod']?.toString() ?? 'other') == entry.key)
                record,
          ],
          amountField: 'totalAmount',
          countLabel: 'paid',
          amountOverride: entry.value,
        );
      }).toList(),
    );
  }

  Widget _buildPaymentStatuses() {
    if (sectionErrors.containsKey('transactions') ||
        sectionErrors.containsKey('product sales')) {
      return _buildReportCard('Payment Status', [
        if (sectionErrors.containsKey('transactions'))
          _buildDataError('transactions'),
        if (sectionErrors.containsKey('product sales'))
          _buildDataError('product sales'),
      ]);
    }

    final counts = <String, int>{};
    final amounts = <String, double>{};
    for (final record in [
      ..._dateSelection.filterEntries(transactions),
      ..._dateSelection.filterEntries(productSales),
    ]) {
      if (record is! Map) continue;
      final status = record['paymentStatus']?.toString() ?? 'paid';
      counts.update(status, (count) => count + 1, ifAbsent: () => 1);
      amounts.update(
        status,
        (total) => total + _salesAmount(record),
        ifAbsent: () => _salesAmount(record),
      );
    }

    if (counts.isEmpty) {
      return _buildReportCard('Payment Status', [
        const Text('No customer transactions or product sales this period.'),
      ]);
    }

    final statuses = counts.keys.toList()
      ..sort((left, right) {
        const priority = {'paid': 0, 'pending': 1, 'cancelled': 2};
        return (priority[left] ?? 3).compareTo(priority[right] ?? 3);
      });
    return _buildReportCard(
      'Payment Status',
      statuses.map((status) {
        final label = status
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
        return _buildSnapshotRow(
          '$label (${counts[status]})',
          _formatCurrency(amounts[status] ?? 0),
        );
      }).toList(),
    );
  }

  Widget _buildRepairSummary() {
    if (sectionErrors.containsKey('repairs')) {
      return _buildReportCard('Repairs', [_buildDataError('repairs')]);
    }

    final statuses = <String, int>{};
    for (final job in _filteredRepairJobs) {
      if (job is! Map) continue;
      final status = job['status']?.toString() ?? 'received';
      statuses.update(status, (count) => count + 1, ifAbsent: () => 1);
    }

    if (statuses.isEmpty) {
      return _buildReportCard('Repairs', [
        const Text('No repair jobs for this period.'),
      ]);
    }

    final entries = statuses.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return _buildReportCard('Repairs', [
      _buildFinancialRow(
        title: 'Payments received',
        section: 'repairs',
        records: _filteredRepairJobs,
        amountField: 'amountPaid',
        countLabel: 'jobs',
      ),
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.key
                      .replaceAll('_', ' ')
                      .split(' ')
                      .map(
                        (word) => word.isEmpty
                            ? word
                            : '${word[0].toUpperCase()}${word.substring(1)}',
                      )
                      .join(' '),
                ),
              ),
              Text('${entry.value}'),
            ],
          ),
        ),
    ]);
  }

  List<Map> get _activeInventoryItems => inventoryItems
      .whereType<Map>()
      .where((item) => item['isActive'] != false)
      .toList();

  Widget _buildInventorySummary() {
    if (sectionErrors.containsKey('inventory')) {
      return _buildReportCard('Current Inventory Snapshot', [
        _buildDataError('inventory'),
      ]);
    }

    final items = _activeInventoryItems;
    var stockUnits = 0;
    var lowStockCount = 0;
    var costValue = 0.0;
    var sellingValue = 0.0;
    for (final item in items) {
      final quantity = _amount(item['quantityInStock']);
      final reorderLevel = _amount(item['reorderLevel'] ?? 5);
      if (quantity <= reorderLevel) lowStockCount++;
      stockUnits += quantity.toInt();
      costValue += quantity * _amount(item['costPrice']);
      sellingValue += quantity * _amount(item['sellingPrice']);
    }

    return _buildReportCard('Current Inventory Snapshot', [
      Text(
        'Current stock levels; not affected by the selected report period.',
        style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12),
      ),
      const SizedBox(height: 12),
      _buildSnapshotRow('Active products', '${items.length}'),
      _buildSnapshotRow('Units in stock', '$stockUnits'),
      _buildSnapshotRow('At or below reorder level', '$lowStockCount'),
      _buildSnapshotRow('Stock value at cost', _formatCurrency(costValue)),
      _buildSnapshotRow('Potential sales value', _formatCurrency(sellingValue)),
    ]);
  }

  Widget _buildSnapshotRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
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
            ElevatedButton(onPressed: fetchReports, child: const Text('Retry')),
          ],
        ),
      ),
    );
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
          'REPORTS',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _buildLoadError()
          : RefreshIndicator(
              onRefresh: () => fetchReports(refresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
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
                          if (sectionErrors.isNotEmpty) ...[
                            _buildPartialDataNotice(),
                            const SizedBox(height: 8),
                          ],
                          _buildSectionTitle('Financial Overview'),
                          _buildSummaryCards(),
                          _buildBalanceNote(),
                          _buildIncomeBreakdown(),
                          _buildExpenseBreakdown(),
                          _buildPaymentMethods(),
                          _buildPaymentStatuses(),
                          _buildRankedCard(
                            title: 'Top Product Sales by Profit',
                            section: 'product sales',
                            records: _paidProductSales,
                            labelField: 'productName',
                            amountField: 'profitAmount',
                            fallbackField: 'item',
                          ),
                          _buildRankedCard(
                            title: 'Top Cyber Services',
                            section: 'cyber services',
                            records: _filteredServiceEntries,
                            labelField: 'serviceName',
                            amountField: 'totalPrice',
                          ),
                          _buildRepairSummary(),
                          _buildSectionTitle(
                            'Inventory',
                            subtitle: 'Current stock snapshot',
                          ),
                          _buildInventorySummary(),
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
