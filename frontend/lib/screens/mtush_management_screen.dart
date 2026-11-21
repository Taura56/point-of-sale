import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/token_service.dart';
import 'inventory_screen.dart';
import 'product_sales_screen.dart';

class _MtushDashboardDisplay {
  const _MtushDashboardDisplay({
    required this.key,
    required this.label,
    required this.icon,
    required this.metricPath,
    this.isCurrency = false,
    this.isTodayMetric = false,
    this.isWeeklyMetric = false,
    this.isWeeklyTithe = false,
    this.isGraph = false,
  });

  final String key;
  final String label;
  final IconData icon;
  final String metricPath;
  final bool isCurrency;
  final bool isTodayMetric;
  final bool isWeeklyMetric;
  final bool isWeeklyTithe;
  final bool isGraph;
}

class MtushManagementScreen extends StatefulWidget {
  const MtushManagementScreen({
    super.key,
    this.initialTab = 0,
    this.showAppBar = true,
  });

  final int initialTab;
  final bool showAppBar;

  @override
  State<MtushManagementScreen> createState() => _MtushManagementScreenState();
}

class _MtushManagementScreenState extends State<MtushManagementScreen> {
  static const List<_MtushDashboardDisplay> _displayOptions = [
    _MtushDashboardDisplay(
      key: 'mtushDailySales',
      label: "Today's Total Sales",
      icon: Icons.payments_outlined,
      metricPath: 'collected.cash',
      isCurrency: true,
      isTodayMetric: true,
    ),
    _MtushDashboardDisplay(
      key: 'mtushTotalRevenue',
      label: 'Total Sales Revenue',
      icon: Icons.point_of_sale,
      metricPath: 'revenue.total',
      isCurrency: true,
    ),
    _MtushDashboardDisplay(
      key: 'mtushInventoryValue',
      label: 'Current Stock Value',
      icon: Icons.inventory_2_outlined,
      metricPath: 'inventory.value',
      isCurrency: true,
    ),
    _MtushDashboardDisplay(
      key: 'mtushReservedStock',
      label: 'LIPA MDOGO ASSETS',
      icon: Icons.bookmark_border,
      metricPath: 'reserved.value',
      isCurrency: true,
    ),
    _MtushDashboardDisplay(
      key: 'mtushLowStock',
      label: 'Low-Stock Products',
      icon: Icons.warning_amber_outlined,
      metricPath: 'lowStock.count',
    ),
    _MtushDashboardDisplay(
      key: 'mtushOutstandingBalances',
      label: 'Outstanding Balances',
      icon: Icons.account_balance_wallet_outlined,
      metricPath: 'outstanding.amount',
      isCurrency: true,
    ),
    _MtushDashboardDisplay(
      key: 'mtushWeeklyTithe',
      label: 'Weekly Tithe (10%)',
      icon: Icons.volunteer_activism_outlined,
      metricPath: 'collected.cash',
      isCurrency: true,
      isWeeklyTithe: true,
    ),
    _MtushDashboardDisplay(
      key: 'mtushWeeklyOperatingProfit',
      label: 'Operating Profit',
      icon: Icons.bar_chart,
      metricPath: 'profit.total',
      isCurrency: true,
      isWeeklyMetric: true,
      isGraph: true,
    ),
  ];

  String? _token;
  String? _businessId;
  String? _role;
  String? _errorMessage;
  Map<String, dynamic> _businessInfo = {};
  Map<String, dynamic> _dashboard = {};
  Map<String, dynamic> _todayMetrics = {};
  Map<String, dynamic> _weeklyMetrics = {};
  Map<String, dynamic> _reportMetrics = {};
  List<dynamic> _orders = [];
  List<dynamic> _products = [];
  List<String> _selectedDisplays = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSavingDisplays = false;
  String _reportPeriod = 'daily';

  bool get _canManageMtush => _role == 'owner' || _role == 'manager';

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  Future<void> _loadWorkspace({bool refresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = !refresh;
      _isRefreshing = refresh;
      _errorMessage = null;
    });

    try {
      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();
      if (token == null || businessId == null || businessId.isEmpty) {
        throw Exception('Login information not found. Please log in again.');
      }

      final settingsResponse = await ApiService.get(
        '/businesses/$businessId/settings',
        token: token,
      );
      final settingsData = settingsResponse is Map
          ? settingsResponse['data']
          : null;
      final role = settingsData is Map
          ? settingsData['role']?.toString()
          : null;
      final business = settingsData is Map ? settingsData['business'] : null;
      if (role == null) {
        throw Exception('Unable to determine your Mtush business role.');
      }

      final responses = await Future.wait([
        ApiService.get(
          '/businesses/$businessId/mtush/installment-orders',
          token: token,
        ),
        ApiService.get('/businesses/$businessId/inventory', token: token),
        if (role == 'owner' || role == 'manager') ...[
          ApiService.get(
            '/businesses/$businessId/mtush/dashboard',
            token: token,
          ),
        ],
        ApiService.get(
          '/businesses/$businessId/dashboard/displays',
          token: token,
        ),
      ]);
      final orders = responses[0] is Map ? responses[0]['orders'] : null;
      final products = responses[1] is Map ? responses[1]['items'] : null;
      final hasManagementAccess = role == 'owner' || role == 'manager';
      final dashboard = hasManagementAccess && responses[2] is Map
          ? responses[2]['metrics']
          : <String, dynamic>{};
      final displayResponse = responses[hasManagementAccess ? 3 : 2];
      final displayData = displayResponse is Map
          ? displayResponse['data']
          : null;
      final displays = displayData is Map ? displayData['displays'] : null;
      if (dashboard is! Map ||
          orders is! List ||
          products is! List ||
          displays is! List ||
          displays.any(
            (display) =>
                display is! String ||
                !_displayOptions.any((option) => option.key == display),
          )) {
        throw Exception('The Mtush workspace returned incomplete data.');
      }

      Map<String, dynamic> todayMetrics = {};
      Map<String, dynamic> weeklyMetrics = {};
      if (hasManagementAccess) {
        final today = DateTime.now();
        final dayStart = DateTime(today.year, today.month, today.day).toUtc();
        final dayEnd = dayStart
            .add(const Duration(days: 1))
            .subtract(const Duration(microseconds: 1));
        final weekStart = DateTime(
          today.year,
          today.month,
          today.day - today.weekday % 7,
        );
        final weekStartUtc = weekStart.toUtc();
        final weekEndUtc = weekStart
            .add(const Duration(days: 7))
            .subtract(const Duration(microseconds: 1))
            .toUtc();
        final summaryResponses = await Future.wait([
          ApiService.get(
            '/businesses/$businessId/mtush/dashboard'
            '?startDate=${Uri.encodeQueryComponent(dayStart.toIso8601String())}'
            '&endDate=${Uri.encodeQueryComponent(dayEnd.toIso8601String())}',
            token: token,
          ),
          ApiService.get(
            '/businesses/$businessId/mtush/dashboard'
            '?startDate=${Uri.encodeQueryComponent(weekStartUtc.toIso8601String())}'
            '&endDate=${Uri.encodeQueryComponent(weekEndUtc.toIso8601String())}',
            token: token,
          ),
        ]);
        final todayResponse = summaryResponses[0];
        final todayData = todayResponse is Map
            ? todayResponse['metrics']
            : null;
        final weeklyResponse = summaryResponses[1];
        final weeklyData = weeklyResponse is Map
            ? weeklyResponse['metrics']
            : null;
        final profitByDay = weeklyData is Map
            ? weeklyData['profitByDay']
            : null;
        if (todayData is! Map ||
            weeklyData is! Map ||
            profitByDay is! List ||
            profitByDay.length != 7 ||
            profitByDay.any((amount) => amount is! num)) {
          throw Exception('Unable to load Mtush dashboard summaries.');
        }
        todayMetrics = Map<String, dynamic>.from(todayData);
        weeklyMetrics = Map<String, dynamic>.from(weeklyData);
      }

      if (!mounted) return;
      setState(() {
        _token = token;
        _businessId = businessId;
        _role = role;
        _businessInfo = business is Map
            ? Map<String, dynamic>.from(business)
            : {};
        _dashboard = Map<String, dynamic>.from(dashboard);
        _todayMetrics = todayMetrics;
        _weeklyMetrics = weeklyMetrics;
        _reportMetrics = Map<String, dynamic>.from(
          hasManagementAccess ? todayMetrics : dashboard,
        );
        _orders = List<dynamic>.from(orders);
        _products = List<dynamic>.from(products);
        _selectedDisplays = List<String>.from(displays);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadReportPeriod(String period) async {
    final token = _token;
    final businessId = _businessId;
    if (token == null || businessId == null || !_canManageMtush) return;

    final now = DateTime.now();
    final start = switch (period) {
      'weekly' => DateTime(now.year, now.month, now.day - now.weekday + 1),
      'monthly' => DateTime(now.year, now.month),
      _ => DateTime(now.year, now.month, now.day),
    };
    final endExclusive = switch (period) {
      'weekly' => start.add(const Duration(days: 7)),
      'monthly' => DateTime(start.year, start.month + 1),
      _ => start.add(const Duration(days: 1)),
    };
    final end = endExclusive.subtract(const Duration(microseconds: 1));

    setState(() {
      _reportPeriod = period;
      _isRefreshing = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.get(
        '/businesses/$businessId/mtush/dashboard'
        '?startDate=${Uri.encodeQueryComponent(start.toUtc().toIso8601String())}'
        '&endDate=${Uri.encodeQueryComponent(end.toUtc().toIso8601String())}',
        token: token,
      );
      final data = response is Map ? response['metrics'] : null;
      if (data is! Map) {
        throw Exception('Unable to load the selected Mtush report period.');
      }
      if (!mounted) return;
      setState(() {
        _reportMetrics = Map<String, dynamic>.from(data);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final views = [_buildOverview(), _buildInstallments(), _buildReports()];
    final titles = ['MTUSH DASHBOARD', 'LIPA MDOGO MDOGO', 'MTUSH REPORTS'];
    final selectedIndex = widget.initialTab.clamp(0, views.length - 1);
    final selectedView = views[selectedIndex];

    if (!widget.showAppBar) return _workspaceBody(selectedView);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          titles[selectedIndex],
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isRefreshing
                ? null
                : () => _loadWorkspace(refresh: true),
            tooltip: 'Refresh Mtush data',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _workspaceBody(selectedView),
    );
  }

  Widget _workspaceBody(Widget view) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _loadWorkspace(refresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (widget.initialTab == 0) {
      return Column(
        children: [
          Expanded(child: view),
          _buildDashboardActions(),
        ],
      );
    }
    return view;
  }

  Widget _buildOverview() {
    return RefreshIndicator(
      onRefresh: () => _loadWorkspace(refresh: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final columns = isWide
              ? 4
              : constraints.maxWidth >= 600
              ? 3
              : 2;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildBusinessInfoCard(),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Dashboard Displays',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_canManageMtush) _buildAddDisplayButton(),
                ],
              ),
              const SizedBox(height: 16),
              if (!_canManageMtush)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Dashboard statistics are available only to owners and managers.',
                    ),
                  ),
                )
              else if (_selectedDisplays.isEmpty)
                _buildEmptyDisplayState()
              else
                _buildSelectedDisplays(columns: columns, isWide: isWide),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSelectedDisplays({required int columns, required bool isWide}) {
    final selectedMetrics = _displayOptions
        .where((display) => _selectedDisplays.contains(display.key))
        .toList();
    final graphMetric = selectedMetrics
        .where((display) => display.isGraph)
        .firstOrNull;
    final regularMetrics = selectedMetrics
        .where((display) => !display.isGraph)
        .toList();
    final children = <Widget>[];

    if (regularMetrics.isNotEmpty) {
      children.add(
        GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isWide
              ? 1.5
              : columns == 2
              ? 0.95
              : 1.25,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: regularMetrics.map(_buildMetricCard).toList(),
        ),
      );
    }

    if (graphMetric != null) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 16));
      children.add(
        SizedBox(
          width: double.infinity,
          height: 300,
          child: _buildWeeklyOperatingProfitCard(graphMetric),
        ),
      );
    }

    return Column(children: children);
  }

  Widget _buildMetricCard(_MtushDashboardDisplay display) {
    if (display.isGraph) return _buildWeeklyOperatingProfitCard(display);
    final metrics = display.isTodayMetric
        ? _todayMetrics
        : display.isWeeklyMetric || display.isWeeklyTithe
        ? _weeklyMetrics
        : _dashboard;
    var value = _metricValue(metrics, display.metricPath);
    if (display.isWeeklyTithe && value is num) value *= 0.1;
    final displayValue = display.isCurrency
        ? _formatDashboardCurrency(value)
        : value?.toString() ?? '0';
    return _buildCard(
      display.label,
      displayValue,
      display.icon,
      onRemove: _isSavingDisplays
          ? null
          : () => _saveDisplays(
              _selectedDisplays.where((key) => key != display.key).toList(),
            ),
    );
  }

  Widget _buildWeeklyOperatingProfitCard(_MtushDashboardDisplay display) {
    final amounts = List<num>.from(_weeklyMetrics['profitByDay'] as List);
    final weekTotal = _metricValue(_weeklyMetrics, display.metricPath);
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final maxMagnitude = amounts.fold<double>(
      0,
      (largest, amount) =>
          amount.abs().toDouble() > largest ? amount.abs().toDouble() : largest,
    );

    return _buildCard(
      display.label,
      'Week total: ${_formatDashboardCurrency(weekTotal)}',
      display.icon,
      onRemove: _isSavingDisplays
          ? null
          : () => _saveDisplays(
              _selectedDisplays.where((key) => key != display.key).toList(),
            ),
      additionalContent: SizedBox(
        height: 150,
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAxisLabel(_formatCompactCurrency(maxMagnitude)),
                  _buildAxisLabel(_formatCompactCurrency(maxMagnitude / 2)),
                  _buildAxisLabel(_formatDashboardCurrency(0)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: CustomPaint(
                      painter: _MtushWeeklyProfitPainter(
                        amounts: amounts
                            .map((amount) => amount.toDouble())
                            .toList(),
                        maxMagnitude: maxMagnitude,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: dayLabels
                        .map(
                          (day) => Expanded(
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAxisLabel(String label) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 9, color: Colors.blueGrey),
    );
  }

  String _formatCompactCurrency(num value) {
    final amount = value.toDouble();
    if (amount.abs() >= 1000000) {
      return 'KSh ${(amount / 1000000).toStringAsFixed(1)}m';
    }
    if (amount.abs() >= 1000) {
      return 'KSh ${(amount / 1000).toStringAsFixed(1)}k';
    }
    return _formatDashboardCurrency(amount);
  }

  Widget _buildAddDisplayButton() {
    final availableDisplays = _displayOptions
        .where((display) => !_selectedDisplays.contains(display.key))
        .toList();

    return PopupMenuButton<String>(
      enabled: !_isSavingDisplays && availableDisplays.isNotEmpty,
      onSelected: (display) {
        _saveDisplays([..._selectedDisplays, display]);
      },
      itemBuilder: (context) => availableDisplays
          .map(
            (display) =>
                PopupMenuItem(value: display.key, child: Text(display.label)),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSavingDisplays)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.add, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              availableDisplays.isEmpty ? 'All Added' : 'Add Display',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDisplayState() {
    return Card(
      elevation: 0,
      color: const Color(0xFFF7FAFD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFDCE6EF)),
      ),
      child: const SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            children: [
              Icon(
                Icons.dashboard_customize_outlined,
                size: 34,
                color: Color(0xFF7890A5),
              ),
              SizedBox(height: 10),
              Text(
                'Your dashboard is ready to customize',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF405A73),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Use Add Display to choose which dashboard cards to show.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF607D8B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessInfoCard() {
    final businessName = _businessInfo['name']?.toString().trim();
    final type = _businessTypeLabel(_businessInfo['businessType']?.toString());
    final location = _businessInfo['location']?.toString().trim() ?? '';
    final phone = _businessInfo['phone']?.toString().trim() ?? '';
    final email = _businessInfo['email']?.toString().trim() ?? '';
    final details = <Widget>[
      if (location.isNotEmpty)
        _businessDetail(Icons.location_on_outlined, location),
      if (phone.isNotEmpty) _businessDetail(Icons.phone_outlined, phone),
      if (email.isNotEmpty) _businessDetail(Icons.email_outlined, email),
    ];
    final identity = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storefront_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            businessName?.isNotEmpty == true ? businessName! : 'Your business',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF17324D),
            ),
          ),
        ),
      ],
    );
    final typeBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: Color(0xFF1565C0),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Card(
      elevation: 0,
      color: const Color(0xFFEAF3FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD5E6FA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 760) {
              return Row(
                children: [
                  Expanded(flex: 2, child: identity),
                  const SizedBox(width: 16),
                  Expanded(child: Align(child: typeBadge)),
                  for (final detail in details) ...[
                    const SizedBox(width: 16),
                    Expanded(child: detail),
                  ],
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 14),
                typeBadge,
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...details,
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _businessDetail(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF56738F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF405A73)),
            ),
          ),
        ],
      ),
    );
  }

  String _businessTypeLabel(String? type) {
    const labels = {
      'cybercafe': 'Cybercafe',
      'phone_repair': 'Phone Repair',
      'accessories_shop': 'Accessories Shop',
      'retail_shop': 'Retail Shop',
      'kinyozi': 'Kinyozi',
      'mtush': 'Mtush',
      'mixed': 'Mixed Business',
      'other': 'Other',
    };
    return labels[type] ?? 'Business';
  }

  Widget _buildCard(
    String title,
    String value,
    IconData icon, {
    VoidCallback? onRemove,
    Widget? additionalContent,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 30, color: const Color(0xFF1565C0)),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (additionalContent != null) ...[
                  const SizedBox(height: 10),
                  additionalContent,
                ],
              ],
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Remove display',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDashboardCurrency(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (amount == null || !amount.isFinite) return 'KSh —';
    final formattedAmount = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return 'KSh $formattedAmount';
  }

  Future<void> _saveDisplays(List<String> displays) async {
    if (_isSavingDisplays) return;
    setState(() {
      _isSavingDisplays = true;
    });

    try {
      final token = _token ?? await TokenService.getToken();
      final businessId = _businessId ?? await TokenService.getBusinessId();
      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      final response = await ApiService.patch(
        '/businesses/$businessId/dashboard/displays',
        {'displays': displays},
        token: token,
      );
      final responseData = response is Map ? response['data'] : null;
      final savedDisplays = responseData is Map
          ? responseData['displays']
          : null;
      if (savedDisplays is! List ||
          savedDisplays.any(
            (display) =>
                display is! String ||
                !_displayOptions.any((option) => option.key == display),
          )) {
        throw Exception('Unable to save dashboard displays.');
      }

      if (!mounted) return;
      setState(() {
        _selectedDisplays = List<String>.from(savedDisplays);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_error(error))));
    } finally {
      if (mounted) setState(() => _isSavingDisplays = false);
    }
  }

  Widget _buildDashboardActions() {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 440;
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: isCompact ? 'Sale' : 'Make a Sale',
                    icon: Icons.point_of_sale,
                    onPressed: _openSaleDialog,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    label: isCompact ? 'Stock' : 'Add Stock',
                    icon: Icons.inventory_2_outlined,
                    onPressed: _openInventory,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    label: 'LIPA MDOGO',
                    icon: Icons.add_card,
                    onPressed: _showCreateOrderDialog,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: const TextStyle(fontSize: 12),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 6),
        ),
      ),
    );
  }

  Future<void> _openSaleDialog() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      builder: (_) =>
          const ProductSalesScreen(openSaleOnOpen: true, isMtush: true),
    );
    if (mounted) await _loadWorkspace(refresh: true);
  }

  Future<void> _openInventory() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => const InventoryScreen(isMtush: true),
      ),
    );
    if (mounted) await _loadWorkspace(refresh: true);
  }

  Widget _buildInstallments() {
    final activeOrders = _orders.where((order) {
      if (order is! Map) return false;
      return _orderBalance(order) > 0 &&
          order['status']?.toString() == 'pending';
    }).toList();
    final orderHistory = _orders.where((order) {
      if (order is! Map) return false;
      return !activeOrders.contains(order);
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _loadWorkspace(refresh: true),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'LIPA MDOGO MDOGO',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF17324D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage customer deposits, installment payments and collections.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Colors.blueGrey),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth >= 420
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _metricCard(
                            'Active installment orders',
                            activeOrders.length.toString(),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _metricCard(
                            'Outstanding balance',
                            _formatCurrency(
                              _metricValue(_dashboard, 'outstanding.amount'),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Customers still paying',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (activeOrders.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No customers have an outstanding balance.'),
                    ),
                  ),
                ...activeOrders.map(_orderCard),
                if (orderHistory.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Completed payments & order history',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ...orderHistory.map(_orderCard),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _showCreateOrderDialog,
                  icon: const Icon(Icons.add_card),
                  label: const Text('New Lipa Mdogo Order'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReports() {
    if (!_canManageMtush) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Mtush financial reports are available to owners and managers.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadReportPeriod(_reportPeriod),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mtush reports',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _reportPeriod,
            decoration: const InputDecoration(
              labelText: 'Reporting period',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Today')),
              DropdownMenuItem(value: 'weekly', child: Text('This week')),
              DropdownMenuItem(value: 'monthly', child: Text('This month')),
            ],
            onChanged: _isRefreshing
                ? null
                : (value) {
                    if (value != null) _loadReportPeriod(value);
                  },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 190,
                child: _metricCard(
                  'Collected sales',
                  _formatCurrency(
                    _metricValue(_reportMetrics, 'collected.cash'),
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: _metricCard(
                  'Sales revenue',
                  _formatCurrency(
                    _metricValue(_reportMetrics, 'revenue.total'),
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: _metricCard(
                  'Cost of goods sold',
                  _formatCurrency(_metricValue(_reportMetrics, 'cogs.total')),
                ),
              ),
              SizedBox(
                width: 190,
                child: _metricCard(
                  'Gross profit',
                  _formatCurrency(_metricValue(_reportMetrics, 'profit.total')),
                ),
              ),
              SizedBox(
                width: 190,
                child: _metricCard(
                  'Current stock value',
                  _formatCurrency(
                    _metricValue(_reportMetrics, 'inventory.value'),
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: _metricCard(
                  'Outstanding installments',
                  _formatCurrency(
                    _metricValue(_reportMetrics, 'outstanding.amount'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(dynamic value) {
    if (value is! Map) return const SizedBox.shrink();
    final order = Map<dynamic, dynamic>.from(value);
    final status = order['status']?.toString() ?? 'pending';
    final balance = _orderBalance(order);
    final payments = order['payments'];

    return Card(
      child: ExpansionTile(
        title: Text(
          order['customerName']?.toString() ?? 'Customer',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${order['customerPhone'] ?? 'No phone'}'
          ' • ${balance == 0 ? 'paid' : 'pending'}'
          ' • ${status.replaceAll('_', ' ')}'
          '\nTotal: ${_formatCurrency(order['totalAmount'])}'
          ' • Paid: ${_formatCurrency(order['amountPaid'])}'
          ' • Balance: ${_formatCurrency(balance)}',
        ),
        children: [
          if (order['items'] is List)
            ...(order['items'] as List).map((item) {
              if (item is! Map) return const SizedBox.shrink();
              return ListTile(
                dense: true,
                title: Text(item['productName']?.toString() ?? 'Product'),
                subtitle: Text(
                  '${item['quantity']} × '
                  '${_formatCurrency(item['unitSellingPrice'])}',
                ),
              );
            }),
          if (payments is List)
            ...payments.map((payment) {
              if (payment is! Map) return const SizedBox.shrink();
              return ListTile(
                dense: true,
                leading: const Icon(Icons.receipt_long),
                title: Text(_formatCurrency(payment['amount'])),
                subtitle: Text(
                  '${payment['paymentMethod'] ?? 'cash'}'
                  ' • ${_formatDate(payment['paidAt'] ?? payment['paymentDate'])}',
                ),
              );
            }),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              if (balance > 0 && status == 'pending')
                TextButton.icon(
                  onPressed: () => _showPaymentDialog(order),
                  icon: const Icon(Icons.add),
                  label: const Text('Add payment'),
                ),
              if (status == 'awaiting_collection')
                TextButton.icon(
                  onPressed: () => _collectOrder(order),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark collected'),
                ),
              if (status != 'collected' && status != 'cancelled')
                TextButton.icon(
                  onPressed: () => _cancelOrder(order),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel order'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateOrderDialog() async {
    final customerName = TextEditingController();
    final customerPhone = TextEditingController();
    final deposit = TextEditingController(text: '0');
    final sellableProducts = _sellableProducts;
    final lines = <_OrderLineForm>[_OrderLineForm(products: sellableProducts)];
    String paymentMethod = 'cash';
    String? initialPaymentIdempotencyKey;
    var saving = false;
    String? error;
    ModalRoute<void>? dialogRoute;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        dialogRoute = ModalRoute.of<void>(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final total = lines.fold<double>(
              0,
              (sum, line) =>
                  sum +
                  (_amount(line.sellingPrice.text) *
                      (_integer(line.quantity.text))),
            );
            return AlertDialog(
              title: const Text('New Lipa Mdogo Mdogo order'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _textField(customerName, 'Customer name', required: true),
                      _textField(
                        customerPhone,
                        'Customer phone number (optional)',
                      ),
                      if (sellableProducts.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  color: Color(0xFF1565C0),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No available stock. Add products to inventory before creating an order.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Products',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: saving
                                  ? null
                                  : () => setDialogState(
                                      () => lines.add(
                                        _OrderLineForm(
                                          products: sellableProducts,
                                        ),
                                      ),
                                    ),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Add product'),
                            ),
                          ],
                        ),
                      ...lines.asMap().entries.map((entry) {
                        final line = entry.value;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: line.itemId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Inventory product',
                                  ),
                                  items: line.products
                                      .map(
                                        (product) => DropdownMenuItem(
                                          value: product['_id'].toString(),
                                          child: Text(
                                            '${product['name']} • available '
                                            '${_availableInventory(product)}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: saving
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            line.itemId = value;
                                            final selected = line.products
                                                .where(
                                                  (product) =>
                                                      product['_id']
                                                          .toString() ==
                                                      value,
                                                )
                                                .firstOrNull;
                                            if (selected != null) {
                                              line.sellingPrice.text =
                                                  selected['sellingPrice']
                                                      ?.toString() ??
                                                  '';
                                            }
                                          });
                                        },
                                ),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final quantityField = _numberField(
                                      line.quantity,
                                      'Quantity',
                                      onChanged: (_) => setDialogState(() {}),
                                    );
                                    final priceField = _numberField(
                                      line.sellingPrice,
                                      'Agreed unit price',
                                      onChanged: (_) => setDialogState(() {}),
                                    );
                                    final removeButton = lines.length > 1
                                        ? IconButton(
                                            tooltip: 'Remove product',
                                            onPressed: saving
                                                ? null
                                                : () => setDialogState(() {
                                                    final removedLine = lines
                                                        .removeAt(entry.key);
                                                    removedLine.dispose();
                                                  }),
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                          )
                                        : null;

                                    if (constraints.maxWidth < 440) {
                                      return Column(
                                        children: [
                                          quantityField,
                                          priceField,
                                          ?removeButton,
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        Expanded(child: quantityField),
                                        const SizedBox(width: 8),
                                        Expanded(child: priceField),
                                        ?removeButton,
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Deposit payment method',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(
                            value: 'mpesa',
                            child: Text('M-Pesa'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setDialogState(() => paymentMethod = value);
                                }
                              },
                      ),
                      _numberField(
                        deposit,
                        'Initial deposit (KSh)',
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Order total: ${_formatCurrency(total)} • '
                          'Balance after deposit: '
                          '${_formatCurrency(total - _amount(deposit.text))}',
                        ),
                      ),
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving || sellableProducts.isEmpty
                      ? null
                      : () async {
                          final depositAmount = double.tryParse(deposit.text);
                          final validLines = lines.every((line) {
                            final quantity = int.tryParse(line.quantity.text);
                            final price = double.tryParse(
                              line.sellingPrice.text,
                            );
                            final product = line.products
                                .where(
                                  (item) =>
                                      item['_id'].toString() == line.itemId,
                                )
                                .firstOrNull;
                            return line.itemId != null &&
                                quantity != null &&
                                quantity > 0 &&
                                price != null &&
                                price >= 0 &&
                                product != null &&
                                quantity <= _availableInventory(product);
                          });
                          if (customerName.text.trim().isEmpty ||
                              depositAmount == null ||
                              depositAmount < 0 ||
                              !validLines) {
                            setDialogState(
                              () => error = 'Enter a customer name and complete the product details; quantities must be available.',
                            );
                            return;
                          }
                          if (depositAmount > total) {
                            setDialogState(
                              () => error =
                                  'Deposit cannot exceed the order total.',
                            );
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await _post('/mtush/installment-orders', {
                              'customerName': customerName.text.trim(),
                              if (customerPhone.text.trim().isNotEmpty)
                                'customerPhone': customerPhone.text.trim(),
                              'items': lines
                                  .map(
                                    (line) => {
                                      'itemId': line.itemId,
                                      'quantity': int.parse(line.quantity.text),
                                      'unitSellingPrice': double.parse(
                                        line.sellingPrice.text,
                                      ),
                                    },
                                  )
                                  .toList(),
                              if (depositAmount > 0)
                                'initialPayment': {
                                  'amount': depositAmount,
                                  'paymentMethod': paymentMethod,
                                  'idempotencyKey':
                                      initialPaymentIdempotencyKey ??=
                                          _idempotencyKey(),
                                },
                            });
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            await _loadWorkspace(refresh: true);
                            _notify(
                              'Installment order created and stock reserved.',
                            );
                          } catch (exception) {
                            if (dialogContext.mounted) {
                              setDialogState(() => error = _error(exception));
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => saving = false);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create order'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() async {
      await dialogRoute?.completed;
      customerName.dispose();
      customerPhone.dispose();
      deposit.dispose();
      for (final line in lines) {
        line.dispose();
      }
    });
  }

  Future<void> _showPaymentDialog(Map<dynamic, dynamic> order) async {
    final amount = TextEditingController(
      text: _orderBalance(order).toStringAsFixed(0),
    );
    String method = 'cash';
    var paymentDate = DateTime.now();
    final paymentIdempotencyKey = _idempotencyKey();
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record installment payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Outstanding balance: ${_formatCurrency(_orderBalance(order))}',
              ),
              _paymentDatePicker(
                paymentDate,
                (date) => setDialogState(() => paymentDate = date),
              ),
              _numberField(amount, 'Payment amount (KSh)'),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
                ],
                onChanged: saving
                    ? null
                    : (value) {
                        if (value != null) setDialogState(() => method = value);
                      },
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final paymentAmount = double.tryParse(amount.text);
                      final isFinalPayment =
                          paymentAmount != null &&
                          (paymentAmount * 100).round() ==
                              (_orderBalance(order) * 100).round();
                      if (paymentAmount == null ||
                          paymentAmount <= 0 ||
                          paymentAmount > _orderBalance(order)) {
                        setDialogState(
                          () => error = 'Payment must be positive and no more than the balance.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await _post(
                          '/mtush/installment-orders/${order['_id']}/payments',
                          {
                            'amount': paymentAmount,
                            'paymentMethod': method,
                            'paymentDate': paymentDate.toIso8601String(),
                            'idempotencyKey': paymentIdempotencyKey,
                          },
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _loadWorkspace(refresh: true);
                        _notify(
                          isFinalPayment
                              ? 'Payment complete. Customer moved to paid order history.'
                              : 'Installment payment recorded.',
                        );
                      } catch (exception) {
                        if (dialogContext.mounted) {
                          setDialogState(() => error = _error(exception));
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Record payment'),
            ),
          ],
        ),
      ),
    ).whenComplete(amount.dispose);
  }

  Future<void> _collectOrder(Map<dynamic, dynamic> order) async {
    final orderId = order['_id']?.toString();
    if (orderId == null) return;
    try {
      await _post('/mtush/installment-orders/$orderId/collect', {});
      await _loadWorkspace(refresh: true);
      _notify('Collection recorded.');
    } catch (error) {
      _notify(_error(error), isError: true);
    }
  }

  Future<void> _cancelOrder(Map<dynamic, dynamic> order) async {
    final orderId = order['_id']?.toString();
    if (orderId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel installment order?'),
        content: const Text(
          'Reserved stock will be released. Existing payment history will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _post('/mtush/installment-orders/$orderId/cancel', {});
      await _loadWorkspace(refresh: true);
      _notify('Order cancelled and stock released.');
    } catch (error) {
      _notify(_error(error), isError: true);
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final token = _token ?? await TokenService.getToken();
    final businessId = _businessId ?? await TokenService.getBusinessId();
    if (token == null || businessId == null) {
      throw Exception('Login information not found. Please log in again.');
    }
    return ApiService.post('/businesses/$businessId$path', data, token: token);
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required && controller.text.trim().isEmpty
            ? (_) => 'Enter $label.'
            : null,
      ),
    );
  }

  Widget _paymentDatePicker(DateTime date, ValueChanged<DateTime> onSelected) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('Payment date: ${_formatDate(date)}'),
      trailing: IconButton(
        tooltip: 'Choose payment date',
        icon: const Icon(Icons.calendar_month_outlined),
        onPressed: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (selected != null) onSelected(selected);
        },
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  dynamic _metricValue(Map<String, dynamic> metrics, String path) {
    dynamic value = metrics;
    for (final segment in path.split('.')) {
      if (value is! Map) return null;
      value = value[segment];
    }
    return value;
  }

  double _orderBalance(Map<dynamic, dynamic> order) {
    final balance =
        _amount(order['totalAmount']) - _amount(order['amountPaid']);
    return balance < 0 ? 0 : balance;
  }

  List<Map<dynamic, dynamic>> get _sellableProducts => _products
      .whereType<Map>()
      .where((product) => _availableInventory(product) > 0)
      .map((product) => Map<dynamic, dynamic>.from(product))
      .toList();

  int _availableInventory(Map product) {
    final stock = _integer(product['quantityInStock']);
    final reserved = _integer(product['reservedQuantity']);
    return math.max(0, stock - reserved);
  }

  int _integer(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatCurrency(dynamic value) =>
      'KSh ${_amount(value).toStringAsFixed(2)}';

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Date not recorded';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _idempotencyKey() {
    final random = math.Random.secure();
    final suffix = List.generate(
      8,
      (_) => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  String _error(Object error) => error is ApiException
      ? error.message
      : error.toString().replaceFirst('Exception: ', '');

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}

class _OrderLineForm {
  _OrderLineForm({required this.products}) {
    itemId = products.isEmpty ? null : products.first['_id']?.toString();
    if (products.isNotEmpty) {
      sellingPrice.text = products.first['sellingPrice']?.toString() ?? '';
    }
  }

  final List<Map<dynamic, dynamic>> products;
  String? itemId;
  final quantity = TextEditingController(text: '1');
  final sellingPrice = TextEditingController();

  void dispose() {
    quantity.dispose();
    sellingPrice.dispose();
  }
}

class _MtushWeeklyProfitPainter extends CustomPainter {
  const _MtushWeeklyProfitPainter({
    required this.amounts,
    required this.maxMagnitude,
  });

  final List<double> amounts;
  final double maxMagnitude;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE3EAF1)
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = size.height * (1 - fraction);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final columnWidth = size.width / amounts.length;
    final barWidth = math.min(20.0, columnWidth * 0.5);
    for (var index = 0; index < amounts.length; index++) {
      final amount = amounts[index];
      final barHeight = maxMagnitude == 0
          ? 0.0
          : (amount.abs() / maxMagnitude * size.height)
                .clamp(0.0, size.height)
                .toDouble();
      if (barHeight == 0) continue;

      final rect = Rect.fromLTWH(
        columnWidth * index + (columnWidth - barWidth) / 2,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      final barPaint = Paint()
        ..color = amount < 0 ? Colors.deepOrange : const Color(0xFF1565C0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MtushWeeklyProfitPainter oldDelegate) {
    return oldDelegate.maxMagnitude != maxMagnitude ||
        oldDelegate.amounts != amounts;
  }
}
