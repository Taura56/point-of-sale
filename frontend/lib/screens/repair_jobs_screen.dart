import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/token_service.dart';
import '../widgets/date_period_filter.dart';
import 'repair_details_screen.dart';

class RepairJobsScreen extends StatefulWidget {
  const RepairJobsScreen({super.key});

  @override
  State<RepairJobsScreen> createState() => _RepairJobsScreenState();
}

class _RepairJobsScreenState extends State<RepairJobsScreen> {
  List<dynamic> repairJobs = [];

  bool isLoading = true;
  String? errorMessage;
  DatePeriodSelection _dateSelection = DatePeriodSelection(
    period: DatePeriod.day,
    anchorDate: DateTime.now(),
  );

  final repairNameController = TextEditingController();
  final priceController = TextEditingController();

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    fetchRepairJobs();
  }

  @override
  void dispose() {
    repairNameController.dispose();
    priceController.dispose();
    super.dispose();
  }

  void showAddRepairDialog() {
    String? formError;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void setFormError(String? message) {
            setDialogState(() {
              formError = message;
            });
          }

          return AlertDialog(
            title: const Text('Add Repair'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: repairNameController,
                      enabled: !isSaving,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Repair name (e.g. mouth pic repair)',
                      ),
                      onChanged: (_) => setFormError(null),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      enabled: !isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price (KSh)',
                      ),
                      onChanged: (_) => setFormError(null),
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
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () => saveRepair(
                        dialogContext,
                        setDialogState,
                        setFormError,
                      ),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Repair'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      repairNameController.clear();
      priceController.clear();
    });
  }

  Future<void> saveRepair(
    BuildContext dialogContext,
    StateSetter setDialogState,
    void Function(String?) setFormError,
  ) async {
    final repairName = repairNameController.text.trim();
    final price = double.tryParse(priceController.text.trim());

    if (repairName.isEmpty || price == null || !price.isFinite || price < 0) {
      setFormError('Enter a repair name and a valid non-negative price.');
      return;
    }

    setDialogState(() {
      isSaving = true;
    });
    setFormError(null);

    try {
      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();

      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      await ApiService.post('/businesses/$businessId/repairs', {
        'repairName': repairName,
        'price': price,
      }, token: token);

      if (!mounted) return;
      if (dialogContext.mounted) Navigator.pop(dialogContext);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Repair job registered successfully.')),
      );

      await fetchRepairJobs();
    } catch (error) {
      if (!mounted) return;

      final message = error is ApiException
          ? error.message
          : error.toString().replaceFirst('Exception: ', '');
      if (dialogContext.mounted) {
        setFormError(message);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
      if (dialogContext.mounted) {
        setDialogState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> fetchRepairJobs() async {
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
        '/businesses/$businessId/repairs',
        token: token,
      );

      if (!mounted) return;

      setState(() {
        repairJobs = response['data'] ?? [];
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error is ApiException
            ? error.message
            : error.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRepairJobs = _dateSelection.filterEntries(repairJobs);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Text(
          'REPAIR JOBS',
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
                      label: 'New Repair',
                      icon: Icons.add,
                      isCompact: isCompact,
                      onPressed: showAddRepairDialog,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: fetchRepairJobs,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SizedBox(
                  width: double.infinity,
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
                      Row(
                        children: [
                          const Text(
                            'Repair Jobs',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Flexible(
                            child: Text(
                              '${_dateSelection.totalLabel}: ${isLoading || errorMessage != null ? '—' : _formatCurrency(_dateSelection.totalFor(repairJobs, 'estimatedCost'))}',
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
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (errorMessage != null)
                        Padding(
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
                                onPressed: fetchRepairJobs,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else if (visibleRepairJobs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No repair jobs for this period.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ...visibleRepairJobs.map(_buildRepairJobCard),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepairJobCard(dynamic job) {
    if (job is! Map) return const SizedBox.shrink();

    final repairName = job['repairName']?.toString().trim();
    final legacyName =
        [job['reportedProblem'], job['deviceType'], job['brand'], job['model']]
            .map((part) => part?.toString().trim() ?? '')
            .where((part) => part.isNotEmpty)
            .join(' - ');
    final displayName = repairName?.isNotEmpty == true
        ? repairName!
        : legacyName.isNotEmpty
        ? legacyName
        : 'Unnamed repair';

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                RepairDetailsScreen(job: Map<String, dynamic>.from(job)),
          ),
        );

        if (result == true && mounted) {
          await fetchRepairJobs();
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE3F2FD),
            child: Icon(Icons.build, color: Color(0xFF1565C0)),
          ),
          title: Text(
            displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Text(
            'Price: KSh ${job['estimatedCost'] ?? 0}',
            style: const TextStyle(
              color: Color(0xFF1565C0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isCompact,
    required VoidCallback? onPressed,
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
