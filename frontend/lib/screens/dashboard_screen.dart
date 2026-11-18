import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/pwa_install_service.dart';
import '../services/token_service.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import 'cyber_services_screen.dart';
import 'expenses_screen.dart';
import 'repair_jobs_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class _DashboardMetric {
  const _DashboardMetric({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const List<_DashboardMetric> _displayOptions = [
    _DashboardMetric(
      key: 'dailyTotalMoney',
      label: "Today's Total Money",
      icon: Icons.payments_outlined,
    ),
    _DashboardMetric(
      key: 'lowStockItems',
      label: 'Low Stock Items',
      icon: Icons.warning_amber_outlined,
    ),
    _DashboardMetric(
      key: 'weeklyTithe',
      label: 'Weekly Tithe (10%)',
      icon: Icons.volunteer_activism_outlined,
    ),
    _DashboardMetric(
      key: 'weeklyOperatingProfit',
      label: 'Operating Profit',
      icon: Icons.bar_chart,
    ),
    _DashboardMetric(
      key: 'dailyExpenses',
      label: "Today's Expenses",
      icon: Icons.money_off,
    ),
  ];

  Map<String, dynamic>? dashboardData;
  Map<String, dynamic>? businessInfo;
  List<String> selectedDisplays = [];
  String? businessName;
  bool isLoading = true;
  bool isSavingDisplays = false;
  bool dashboardStatsForbidden = false;
  bool _isPwaInstalled = false;
  String? errorMessage;
  final _pwaInstallService = PwaInstallService();

  @override
  void initState() {
    super.initState();
    _isPwaInstalled = _pwaInstallService.isInstalled;
    loadDashboard();
  }

  Future<void> _installApp() async {
    final result = await _pwaInstallService.promptInstall();
    if (!mounted) return;

    switch (result) {
      case PwaInstallResult.accepted:
      case PwaInstallResult.alreadyInstalled:
        setState(() => _isPwaInstalled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business Manager is installed.')),
        );
      case PwaInstallResult.dismissed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App installation was dismissed.')),
        );
      case PwaInstallResult.manual:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Install Business Manager'),
            content: const Text(
              'Android Chrome: Open the menu (⋮) and choose “Install app” '
              'or “Add to Home screen”.\n\n'
              'iPhone or iPad Safari: Tap Share, then “Add to Home Screen”.\n\n'
              'Desktop: Use the install icon in the address bar or choose '
              '“Install Business Manager” from the browser menu.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          ),
        );
    }
  }

  Future<void> refreshDashboard() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    await loadDashboard();
  }

  Future<void> logout() async {
    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> loadDashboard() async {
    if (!mounted) return;

    var requestingDashboardStats = false;
    setState(() {
      dashboardStatsForbidden = false;
      errorMessage = null;
      isLoading = true;
    });

    try {
      final token = await TokenService.getToken();

      if (token == null) {
        throw Exception('Please log in again.');
      }

      final businessId = await TokenService.getBusinessId();

      if (businessId == null || businessId.isEmpty) {
        throw Exception('Business ID not found. Please log in again.');
      }

      final settingsResponse = await ApiService.get(
        '/businesses/$businessId/settings',
        token: token,
      );
      final settingsData = settingsResponse is Map
          ? settingsResponse['data']
          : null;
      final businessData = settingsData is Map
          ? settingsData['business']
          : null;
      final name = businessData is Map
          ? businessData['name']?.toString()
          : null;

      if (name == null || name.trim().isEmpty) {
        throw Exception('Business name could not be loaded.');
      }

      if (!mounted) return;
      setState(() {
        businessName = name.trim();
        businessInfo = Map<String, dynamic>.from(businessData);
      });

      requestingDashboardStats = true;
      final today = DateTime.now();
      final dayStart = DateTime(today.year, today.month, today.day);
      final dayEnd = DateTime(today.year, today.month, today.day + 1);
      final weekStart = DateTime(
        dayStart.year,
        dayStart.month,
        dayStart.day - dayStart.weekday % 7,
      );
      final weekBoundaries = List.generate(
        8,
        (index) => DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + index,
        ).toUtc().toIso8601String(),
      );
      final dashboardEndpoint =
          '/businesses/$businessId/dashboard'
          '?dayStart=${Uri.encodeQueryComponent(dayStart.toUtc().toIso8601String())}'
          '&dayEnd=${Uri.encodeQueryComponent(dayEnd.toUtc().toIso8601String())}'
          '&weekBoundaries=${Uri.encodeQueryComponent(jsonEncode(weekBoundaries))}';
      final responses = await Future.wait([
        ApiService.get(dashboardEndpoint, token: token),
        ApiService.get(
          '/businesses/$businessId/dashboard/displays',
          token: token,
        ),
      ]);
      final response = responses[0];
      final displayResponse = responses[1];
      final dashboard = response is Map ? response['dashboard'] : null;
      final displayData = displayResponse is Map
          ? displayResponse['data']
          : null;
      final displays = displayData is Map ? displayData['displays'] : null;
      if (dashboard is! Map ||
          dashboard['dailyTotalMoney'] is! num ||
          dashboard['weeklyTithe'] is! num ||
          dashboard['weeklyTotalMoney'] is! num ||
          dashboard['lowStockItems'] is! num ||
          dashboard['dailyExpenses'] is! num ||
          dashboard['weeklyMoneyByDay'] is! List ||
          dashboard['weeklyMoneyByDay'].length != 7 ||
          dashboard['weeklyMoneyByDay'].any((amount) => amount is! num) ||
          displays is! List ||
          displays.any(
            (display) =>
                display is! String ||
                !_displayOptions.any((option) => option.key == display),
          )) {
        throw Exception('Unable to load dashboard displays.');
      }

      if (!mounted) return;

      setState(() {
        businessName = name.trim();
        businessInfo = Map<String, dynamic>.from(businessData);
        dashboardData = Map<String, dynamic>.from(dashboard);
        selectedDisplays = List<String>.from(displays);
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      final statsForbidden =
          requestingDashboardStats &&
          error is ApiException &&
          error.statusCode == 403;
      setState(() {
        dashboardStatsForbidden = statsForbidden;
        errorMessage = statsForbidden
            ? 'Dashboard statistics are available only to owners and managers.'
            : _formatError(error);
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),

      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              businessName ?? (isLoading ? 'Loading business...' : 'Business'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Text(
              'BUSINESS MANAGEMENT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        toolbarHeight: 72,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          if (kIsWeb && !_isPwaInstalled)
            IconButton(
              icon: const Icon(Icons.install_mobile),
              tooltip: 'Install App',
              onPressed: _installApp,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh dashboard',
            onPressed: refreshDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: logout,
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  if (!dashboardStatsForbidden)
                    ElevatedButton(
                      onPressed: refreshDashboard,
                      child: const Text('Retry'),
                    ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final columns = isWide
                    ? 4
                    : constraints.maxWidth >= 600
                    ? 3
                    : 2;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          _buildAddDisplayButton(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (selectedDisplays.isEmpty)
                        _buildEmptyDisplayState()
                      else
                        _buildSelectedDisplays(
                          columns: columns,
                          isWide: isWide,
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSelectedDisplays({required int columns, required bool isWide}) {
    final selectedMetrics = _displayOptions
        .where((display) => selectedDisplays.contains(display.key))
        .toList();
    final children = <Widget>[];
    var index = 0;
    while (index < selectedMetrics.length) {
      if (selectedMetrics[index].key == 'weeklyOperatingProfit') {
        children.add(
          SizedBox(
            width: double.infinity,
            height: 300,
            child: _buildWeeklyOperatingProfitCard(selectedMetrics[index]),
          ),
        );
        index++;
      } else {
        final regularMetrics = <_DashboardMetric>[];
        while (index < selectedMetrics.length &&
            selectedMetrics[index].key != 'weeklyOperatingProfit') {
          regularMetrics.add(selectedMetrics[index]);
          index++;
        }
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

      if (index < selectedMetrics.length) {
        children.add(const SizedBox(height: 16));
      }
    }

    return Column(children: children);
  }

  void _openScreen(Widget screen) {
    Navigator.pop(context);

    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  String _formatError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Widget _buildAddDisplayButton() {
    final availableDisplays = _displayOptions
        .where((display) => !selectedDisplays.contains(display.key))
        .toList();

    if (_displayOptions.isEmpty) {
      return OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Display options will be added later.'),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Display'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1565C0),
        ),
      );
    }

    return PopupMenuButton<String>(
      enabled: !isSavingDisplays && availableDisplays.isNotEmpty,
      onSelected: (display) {
        _saveDisplays([...selectedDisplays, display]);
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
            if (isSavingDisplays)
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

  Widget _buildMetricCard(_DashboardMetric metric) {
    final value = dashboardData?[metric.key] ?? 0;
    final displayValue =
        metric.key == 'dailyTotalMoney' ||
            metric.key == 'weeklyTithe' ||
            metric.key == 'dailyExpenses'
        ? _formatCurrency(value)
        : '$value';
    return _buildCard(
      metric.label,
      displayValue,
      metric.icon,
      onRemove: isSavingDisplays
          ? null
          : () => _saveDisplays(
              selectedDisplays.where((key) => key != metric.key).toList(),
            ),
    );
  }

  Widget _buildWeeklyOperatingProfitCard(_DashboardMetric metric) {
    final amounts = List<num>.from(dashboardData!['weeklyMoneyByDay'] as List);
    final weekTotal = dashboardData!['weeklyTotalMoney'];
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final maxMagnitude = amounts.fold<double>(
      0,
      (largest, amount) =>
          amount.abs().toDouble() > largest ? amount.abs().toDouble() : largest,
    );

    return _buildCard(
      metric.label,
      'Week total: ${_formatCurrency(weekTotal)}',
      metric.icon,
      onRemove: isSavingDisplays
          ? null
          : () => _saveDisplays(
              selectedDisplays.where((key) => key != metric.key).toList(),
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
                  _buildAxisLabel(_formatCurrency(0)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: CustomPaint(
                      painter: _WeeklyMoneyChartPainter(
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

  String _formatCurrency(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (amount == null || !amount.isFinite) return 'KSh —';
    final formattedAmount = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return 'KSh $formattedAmount';
  }

  String _formatCompactCurrency(num value) {
    final amount = value.toDouble();
    if (amount.abs() >= 1000000) {
      return 'KSh ${(amount / 1000000).toStringAsFixed(1)}m';
    }
    if (amount.abs() >= 1000) {
      return 'KSh ${(amount / 1000).toStringAsFixed(1)}k';
    }
    return _formatCurrency(amount);
  }

  Future<void> _saveDisplays(List<String> displays) async {
    if (isSavingDisplays) return;
    setState(() {
      isSavingDisplays = true;
    });

    try {
      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();
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
        selectedDisplays = List<String>.from(savedDisplays);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_formatError(error))));
    } finally {
      if (mounted) {
        setState(() {
          isSavingDisplays = false;
        });
      }
    }
  }

  String _businessTypeLabel(String? type) {
    const labels = {
      'cybercafe': 'Cybercafe',
      'phone_repair': 'Phone Repair',
      'accessories_shop': 'Accessories Shop',
      'retail_shop': 'Retail Shop',
      'kinyozi': 'Kinyozi',
      'mixed': 'Mixed Business',
      'other': 'Other',
    };
    return labels[type] ?? 'Business';
  }

  Widget _buildBusinessInfoCard() {
    final info = businessInfo ?? {};
    final businessType = _businessTypeLabel(info['businessType']?.toString());
    final location = info['location']?.toString().trim() ?? '';
    final phone = info['phone']?.toString().trim() ?? '';
    final email = info['email']?.toString().trim() ?? '';
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
            businessName ?? 'Your business',
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
        businessType,
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

  // Builds the navigation drawer.
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF1565C0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset(
                  'assets/app_logo.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                Text(
                  'Business Manager',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Business Management System',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text('Cyber Services & Sales'),
            onTap: () => _openScreen(const CyberServicesScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text('Repair Jobs'),
            onTap: () => _openScreen(const RepairJobsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Inventory'),
            onTap: () => _openScreen(const InventoryScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.money_off),
            title: const Text('Expenses'),
            onTap: () => _openScreen(const ExpensesScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Reports'),
            onTap: () => _openScreen(const ReportsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => _openScreen(const SettingsScreen()),
          ),
        ],
      ),
    );
  }

  // Builds an individual dashboard card.
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
}

class _WeeklyMoneyChartPainter extends CustomPainter {
  const _WeeklyMoneyChartPainter({
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
  bool shouldRepaint(_WeeklyMoneyChartPainter oldDelegate) {
    return oldDelegate.maxMagnitude != maxMagnitude ||
        oldDelegate.amounts != amounts;
  }
}
