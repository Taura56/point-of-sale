import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/token_service.dart';

class RepairDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const RepairDetailsScreen({super.key, required this.job});

  @override
  State<RepairDetailsScreen> createState() => _RepairDetailsScreenState();
}

class _RepairDetailsScreenState extends State<RepairDetailsScreen> {
  late final TextEditingController diagnosisController;
  late final TextEditingController repairCostController;
  late final TextEditingController amountPaidController;
  late final TextEditingController notesController;

  late String selectedStatus;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    diagnosisController = TextEditingController(
      text: widget.job['diagnosis'] ?? '',
    );
    repairCostController = TextEditingController(
      text: (widget.job['repairCost'] ?? 0).toString(),
    );
    amountPaidController = TextEditingController(
      text: (widget.job['amountPaid'] ?? 0).toString(),
    );
    notesController = TextEditingController(text: widget.job['notes'] ?? '');
    selectedStatus = widget.job['status'] ?? 'received';
  }

  @override
  void dispose() {
    diagnosisController.dispose();
    repairCostController.dispose();
    amountPaidController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> updateRepair() async {
    final repairCost = double.tryParse(repairCostController.text.trim());
    final amountPaid = double.tryParse(amountPaidController.text.trim());

    if (repairCost == null ||
        !repairCost.isFinite ||
        repairCost < 0 ||
        amountPaid == null ||
        !amountPaid.isFinite ||
        amountPaid < 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid repair cost and payment amounts.'),
        ),
      );
      return;
    }

    if (amountPaid > repairCost) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount paid cannot exceed repair cost.')),
      );
      return;
    }

    try {
      setState(() {
        isSaving = true;
      });

      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();

      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      final jobId = widget.job['_id'] ?? widget.job['id'];
      if (jobId == null) {
        throw Exception('Repair job ID not found.');
      }

      await ApiService.patch('/businesses/$businessId/repairs/$jobId', {
        'status': selectedStatus,
        'diagnosis': diagnosisController.text.trim(),
        'repairCost': repairCost,
        'amountPaid': amountPaid,
        'notes': notesController.text.trim(),
      }, token: token);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Repair updated successfully.')),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3F2FD)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1565C0),
                fontSize: 20,
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

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.blueGrey.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString().isNotEmpty == true
                  ? value.toString()
                  : 'Not provided',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(labelText: label);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final repairName = job['repairName']?.toString().trim();
    final isSimpleRepair = repairName?.isNotEmpty == true;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Text(
          'REPAIR DETAILS',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSimpleRepair)
                  _buildSection('Repair Information', [
                    _buildDetailRow('Repair Name', repairName),
                    _buildDetailRow(
                      'Price',
                      'KSh ${job['estimatedCost'] ?? 0}',
                    ),
                    _buildDetailRow(
                      'Current Status',
                      (job['status'] ?? 'received')
                          .toString()
                          .replaceAll('_', ' ')
                          .toUpperCase(),
                    ),
                    _buildDetailRow('Additional Notes', job['notes']),
                  ])
                else ...[
                  _buildSection('Customer Information', [
                    _buildDetailRow('Customer Name', job['customerName']),
                    _buildDetailRow('Phone Number', job['customerPhone']),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection('Device Information', [
                    _buildDetailRow('Device Type', job['deviceType']),
                    _buildDetailRow('Brand', job['brand']),
                    _buildDetailRow('Model', job['model']),
                    _buildDetailRow('Reported Problem', job['reportedProblem']),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection('Repair Information', [
                    _buildDetailRow(
                      'Estimated Cost',
                      'KSh ${job['estimatedCost'] ?? 0}',
                    ),
                    _buildDetailRow(
                      'Current Status',
                      (job['status'] ?? 'received')
                          .toString()
                          .replaceAll('_', ' ')
                          .toUpperCase(),
                    ),
                    _buildDetailRow('Additional Notes', job['notes']),
                  ]),
                ],
                const SizedBox(height: 20),
                _buildSection('Manage Repair', [
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: _inputDecoration('Repair Status'),
                    items: const [
                      DropdownMenuItem(
                        value: 'received',
                        child: Text('Received'),
                      ),
                      DropdownMenuItem(
                        value: 'diagnosing',
                        child: Text('Diagnosing'),
                      ),
                      DropdownMenuItem(
                        value: 'waiting_for_approval',
                        child: Text('Waiting for Approval'),
                      ),
                      DropdownMenuItem(
                        value: 'waiting_for_parts',
                        child: Text('Waiting for Parts'),
                      ),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('In Progress'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(
                        value: 'collected',
                        child: Text('Collected'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Cancelled'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedStatus = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: diagnosisController,
                    decoration: _inputDecoration('Diagnosis'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: repairCostController,
                    decoration: _inputDecoration('Final Repair Cost (KSh)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountPaidController,
                    decoration: _inputDecoration('Amount Paid (KSh)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    decoration: _inputDecoration('Additional Notes'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : updateRepair,
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(isSaving ? 'Saving...' : 'Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
