import 'package:flutter/material.dart';

import 'account_creation_screen.dart';

class BusinessTypeScreen extends StatefulWidget {
  const BusinessTypeScreen({super.key});

  @override
  State<BusinessTypeScreen> createState() => _BusinessTypeScreenState();
}

class _BusinessTypeScreenState extends State<BusinessTypeScreen> {
  String? _selectedType;

  final List<Map<String, dynamic>> _businessTypes = [
    {'type': 'cybercafe', 'name': 'Cyber Cafe', 'icon': Icons.computer},
    {
      'type': 'phone_repair',
      'name': 'Phone Repair',
      'icon': Icons.phone_android,
    },
    {
      'type': 'accessories_shop',
      'name': 'Accessories Shop',
      'icon': Icons.headphones,
    },
    {'type': 'retail_shop', 'name': 'Retail Shop', 'icon': Icons.store},
    {'type': 'kinyozi', 'name': 'Kinyozi', 'icon': Icons.content_cut},
    {'type': 'mtush', 'name': 'Mtush', 'icon': Icons.checkroom},
    {'type': 'mixed', 'name': 'Mixed Business', 'icon': Icons.business},
    {'type': 'other', 'name': 'Other', 'icon': Icons.more_horiz},
  ];

  void _continue() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your business type')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AccountCreationScreen(businessType: _selectedType!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1565C0);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/app_logo.png', height: 70),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome to Business Manager',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'First, tell us what type of business you run.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  const SizedBox(height: 30),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _businessTypes.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.5,
                        ),
                    itemBuilder: (context, index) {
                      final business = _businessTypes[index];
                      final type = business['type'] as String;

                      final isAvailable = type == 'mtush' || type == 'mixed';
                      final selected = _selectedType == type;

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          if (!isAvailable) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${business['name']} is coming soon!',
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            _selectedType = type;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFE3F2FD)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? primaryBlue
                                  : const Color(0xFFD5E3F0),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                business['icon'],
                                size: 30,
                                color: isAvailable ? primaryBlue : Colors.grey,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                business['name'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isAvailable
                                      ? Colors.black87
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 5),
                              if (selected)
                                const Icon(
                                  Icons.check_circle,
                                  color: primaryBlue,
                                  size: 18,
                                )
                              else if (!isAvailable)
                                const Text(
                                  'Coming Soon',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _continue,
                    child: const Text('CONTINUE'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
