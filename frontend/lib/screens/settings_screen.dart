import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/token_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Map<String, String> _businessTypes = {
    'cybercafe': 'Cybercafe',
    'phone_repair': 'Phone Repair',
    'accessories_shop': 'Accessories Shop',
    'retail_shop': 'Retail Shop',
    'kinyozi': 'Kinyozi',
    'mtush': 'Mtush',
    'mixed': 'Mixed Business',
    'other': 'Other',
  };

  final _businessNameController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _businessLocationController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<dynamic> members = [];
  String _businessType = 'mixed';
  String? _businessId;
  String? _currentUserId;
  String? _role;
  String? _teamError;
  String? errorMessage;
  bool isLoading = true;
  bool isSavingBusiness = false;
  bool isSavingProfile = false;
  bool isChangingPassword = false;

  bool get _isOwner => _role == 'owner';
  bool get _canManageTeam => _role == 'owner' || _role == 'manager';

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _businessLocationController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _formatError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> loadSettings() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await TokenService.getToken();
      final businessId = await TokenService.getBusinessId();
      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      final responses = await Future.wait([
        ApiService.get('/auth/me', token: token),
        ApiService.get('/businesses/$businessId/settings', token: token),
      ]);
      final userData = responses[0] is Map ? responses[0]['data'] : null;
      final settingsData = responses[1] is Map ? responses[1]['data'] : null;
      final businessData = settingsData is Map
          ? settingsData['business']
          : null;
      if (userData is! Map || businessData is! Map) {
        throw Exception('Unable to load account and business settings.');
      }

      final role = settingsData['role']?.toString();
      var loadedMembers = <dynamic>[];
      String? loadedTeamError;

      if (role == 'owner' || role == 'manager') {
        try {
          final memberResponse = await ApiService.get(
            '/businesses/$businessId/members',
            token: token,
          );
          final memberData = memberResponse is Map
              ? memberResponse['data']
              : null;
          if (memberData is! List) {
            throw Exception('Unable to load business members.');
          }
          loadedMembers = List<dynamic>.from(memberData);
        } catch (error) {
          loadedTeamError = _formatError(error);
        }
      } else {
        loadedTeamError = 'Only owners and managers can manage team members.';
      }

      if (!mounted) return;
      setState(() {
        _currentUserId = userData['id']?.toString();
        _businessId = businessId;
        _role = role;
        _businessNameController.text = businessData['name']?.toString() ?? '';
        _businessPhoneController.text = businessData['phone']?.toString() ?? '';
        _businessEmailController.text = businessData['email']?.toString() ?? '';
        _businessLocationController.text =
            businessData['location']?.toString() ?? '';
        final businessType = businessData['businessType']?.toString();
        _businessType = _businessTypes.containsKey(businessType)
            ? businessType!
            : 'other';
        _fullNameController.text = userData['fullName']?.toString() ?? '';
        _emailController.text = userData['email']?.toString() ?? '';
        _phoneController.text = userData['phone']?.toString() ?? '';
        members = loadedMembers;
        _teamError = loadedTeamError;
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(labelText: label);
  }

  Widget _sectionCard({
    required String title,
    String? description,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 13),
              ),
            ],
            const Divider(height: 24, color: Color(0xFFE3F2FD)),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _saveButton({
    required String label,
    required bool isSaving,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: isSaving ? null : onPressed,
        icon: isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_outlined),
        label: Text(isSaving ? 'Saving...' : label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveBusinessProfile() async {
    if (_businessNameController.text.trim().isEmpty) {
      _showMessage('Enter a business name.');
      return;
    }
    final businessEmail = _businessEmailController.text.trim();
    if (businessEmail.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(businessEmail)) {
      _showMessage('Enter a valid business email address.');
      return;
    }

    setState(() {
      isSavingBusiness = true;
    });
    try {
      final token = await TokenService.getToken();
      final businessId = _businessId;
      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      await ApiService.patch('/businesses/$businessId/settings', {
        'name': _businessNameController.text.trim(),
        'businessType': _businessType,
        'phone': _businessPhoneController.text.trim(),
        'email': businessEmail,
        'location': _businessLocationController.text.trim(),
      }, token: token);

      _showMessage('Business profile updated.');
    } catch (error) {
      _showMessage(_formatError(error));
    } finally {
      if (mounted) {
        setState(() {
          isSavingBusiness = false;
        });
      }
    }
  }

  Future<void> _saveAccountProfile() async {
    final name = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    if (name.isEmpty) {
      _showMessage('Enter your full name.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('Enter a valid email address.');
      return;
    }

    setState(() {
      isSavingProfile = true;
    });
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      await ApiService.patch('/auth/me', {
        'fullName': name,
        'email': email,
        'phone': _phoneController.text.trim(),
      }, token: token);

      _showMessage('Account profile updated.');
    } catch (error) {
      _showMessage(_formatError(error));
    } finally {
      if (mounted) {
        setState(() {
          isSavingProfile = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      _showMessage('Enter your current and new passwords.');
      return;
    }
    if (newPassword.length < 8) {
      _showMessage('New password must contain at least 8 characters.');
      return;
    }
    if (newPassword != _confirmPasswordController.text) {
      _showMessage('New passwords do not match.');
      return;
    }

    setState(() {
      isChangingPassword = true;
    });
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      await ApiService.patch('/auth/me/password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }, token: token);

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showMessage('Password changed successfully.');
    } catch (error) {
      _showMessage(_formatError(error));
    } finally {
      if (mounted) {
        setState(() {
          isChangingPassword = false;
        });
      }
    }
  }

  Future<void> _loadMembers() async {
    try {
      final token = await TokenService.getToken();
      final businessId = _businessId;
      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      final response = await ApiService.get(
        '/businesses/$businessId/members',
        token: token,
      );
      final data = response is Map ? response['data'] : null;
      if (data is! List) {
        throw Exception('Unable to load business members.');
      }
      if (!mounted) return;

      setState(() {
        members = List<dynamic>.from(data);
        _teamError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _teamError = _formatError(error);
      });
    }
  }

  Future<void> _showAddMemberDialog() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedRole = 'employee';
    var isSaving = false;
    String? formError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> addMember() async {
            if (formKey.currentState?.validate() != true) return;
            setDialogState(() {
              isSaving = true;
              formError = null;
            });

            try {
              final token = await TokenService.getToken();
              final businessId = _businessId;
              if (token == null || businessId == null) {
                throw Exception(
                  'Login information not found. Please log in again.',
                );
              }

              await ApiService.post('/businesses/$businessId/members', {
                'email': emailController.text.trim(),
                'role': selectedRole,
              }, token: token);
              if (!mounted || !dialogContext.mounted) return;

              Navigator.pop(dialogContext);
              _showMessage('Team member added.');
              await _loadMembers();
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                formError = _formatError(error);
              });
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() {
                  isSaving = false;
                });
              }
            }
          }

          final roles = _isOwner
              ? const ['manager', 'employee']
              : const ['employee'];
          return AlertDialog(
            title: const Text('Add Team Member'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: emailController,
                      enabled: !isSaving,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration('Account Email'),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(email)
                            ? null
                            : 'Enter a valid account email.';
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: _inputDecoration('Role'),
                      items: roles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(
                                role[0].toUpperCase() + role.substring(1),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() {
                                  selectedRole = value;
                                });
                              }
                            },
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
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : addMember,
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
                    : const Text('Add Member'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(emailController.dispose);
  }

  Future<void> _changeMemberRole(Map<dynamic, dynamic> member) async {
    final memberId = member['id']?.toString();
    final oldRole = member['role']?.toString() ?? 'employee';
    if (memberId == null || memberId.isEmpty || !_isOwner) return;

    var selectedRole = oldRole == 'manager' ? 'manager' : 'employee';
    var isSaving = false;
    String? formError;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> saveRole() async {
            setDialogState(() {
              isSaving = true;
              formError = null;
            });
            try {
              final token = await TokenService.getToken();
              final businessId = _businessId;
              if (token == null || businessId == null) {
                throw Exception(
                  'Login information not found. Please log in again.',
                );
              }

              await ApiService.patch(
                '/businesses/$businessId/members/$memberId',
                {'role': selectedRole},
                token: token,
              );
              if (!mounted || !dialogContext.mounted) return;

              Navigator.pop(dialogContext);
              _showMessage('Team member role updated.');
              await _loadMembers();
            } catch (error) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                formError = _formatError(error);
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
            title: Text('Update ${member['fullName'] ?? 'member'} role'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: _inputDecoration('Role'),
                  items: const [
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(
                      value: 'employee',
                      child: Text('Employee'),
                    ),
                  ],
                  onChanged: isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedRole = value;
                            });
                          }
                        },
                ),
                if (formError != null) ...[
                  const SizedBox(height: 12),
                  Text(formError!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : saveRole,
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
                    : const Text('Save Role'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeMember(Map<dynamic, dynamic> member) async {
    final memberId = member['id']?.toString();
    if (memberId == null || memberId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove team member?'),
        content: Text(
          '${member['fullName'] ?? 'This member'} will lose access to this business.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final token = await TokenService.getToken();
      final businessId = _businessId;
      if (token == null || businessId == null) {
        throw Exception('Login information not found. Please log in again.');
      }

      await ApiService.delete(
        '/businesses/$businessId/members/$memberId',
        token: token,
      );
      if (!mounted) return;
      _showMessage('Team member removed.');
      await _loadMembers();
    } catch (error) {
      _showMessage(_formatError(error));
    }
  }

  Widget _buildTeamCard(Map<dynamic, dynamic> member) {
    final isOwner = member['isOwner'] == true;
    final memberId = member['id']?.toString();
    final isSelf = memberId != null && memberId == _currentUserId;
    final memberRole = member['role']?.toString() ?? 'employee';
    final canRemove =
        !isOwner &&
        !isSelf &&
        (_isOwner || (_role == 'manager' && memberRole == 'employee'));
    final canChangeRole = _isOwner && !isOwner && !isSelf;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE3F2FD)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE3F2FD),
          child: Icon(
            isOwner ? Icons.verified_user_outlined : Icons.person_outline,
            color: const Color(0xFF1565C0),
          ),
        ),
        title: Text(
          member['fullName']?.toString() ?? 'Unnamed member',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${member['email'] ?? ''}\n'
          '${isOwner ? 'Owner' : memberRole[0].toUpperCase() + memberRole.substring(1)}',
        ),
        isThreeLine: true,
        trailing: canChangeRole || canRemove
            ? PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'role') _changeMemberRole(member);
                  if (action == 'remove') _removeMember(member);
                },
                itemBuilder: (context) => [
                  if (canChangeRole)
                    const PopupMenuItem(
                      value: 'role',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.manage_accounts_outlined),
                        title: Text('Change role'),
                      ),
                    ),
                  if (canRemove)
                    const PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.person_remove_outlined,
                          color: Colors.red,
                        ),
                        title: Text('Remove'),
                      ),
                    ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildTeamSection() {
    if (!_canManageTeam) {
      return _sectionCard(
        title: 'Team Members',
        description: 'Team management is available to owners and managers.',
        children: const [],
      );
    }

    return _sectionCard(
      title: 'Team Members',
      description: _isOwner
          ? 'Manage business access and member roles.'
          : 'Managers can add or remove employees.',
      children: [
        if (_teamError != null) ...[
          Text(_teamError!, style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: _loadMembers, child: const Text('Retry')),
        ] else if (members.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('No team members are registered for this business.'),
          )
        else
          ...members.whereType<Map>().map(_buildTeamCard),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _showAddMemberDialog,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add Member'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsContent() {
    final readOnlyBusiness = !_isOwner;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionCard(
                  title: 'Business Profile',
                  description: readOnlyBusiness
                      ? 'Only the business owner can edit business details.'
                      : 'Update the details used to identify your business.',
                  children: [
                    TextFormField(
                      controller: _businessNameController,
                      enabled: !readOnlyBusiness && !isSavingBusiness,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration('Business Name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _businessType,
                      decoration: _inputDecoration('Business Type'),
                      items: _businessTypes.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: readOnlyBusiness || isSavingBusiness
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _businessType = value;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessPhoneController,
                      enabled: !readOnlyBusiness && !isSavingBusiness,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration('Business Phone'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessEmailController,
                      enabled: !readOnlyBusiness && !isSavingBusiness,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration('Business Email'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessLocationController,
                      enabled: !readOnlyBusiness && !isSavingBusiness,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration('Location'),
                    ),
                    if (!readOnlyBusiness) ...[
                      const SizedBox(height: 16),
                      _saveButton(
                        label: 'Save Business Profile',
                        isSaving: isSavingBusiness,
                        onPressed: _saveBusinessProfile,
                      ),
                    ],
                  ],
                ),
                _sectionCard(
                  title: 'Account Profile',
                  description: 'Update your personal account information.',
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      enabled: !isSavingProfile,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration('Full Name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      enabled: !isSavingProfile,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration('Email Address'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !isSavingProfile,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration('Phone Number'),
                    ),
                    const SizedBox(height: 16),
                    _saveButton(
                      label: 'Save Account Profile',
                      isSaving: isSavingProfile,
                      onPressed: _saveAccountProfile,
                    ),
                  ],
                ),
                _sectionCard(
                  title: 'Change Password',
                  description: 'Use a new password with at least 8 characters.',
                  children: [
                    TextField(
                      controller: _currentPasswordController,
                      enabled: !isChangingPassword,
                      obscureText: true,
                      decoration: _inputDecoration('Current Password'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordController,
                      enabled: !isChangingPassword,
                      obscureText: true,
                      decoration: _inputDecoration('New Password'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      enabled: !isChangingPassword,
                      obscureText: true,
                      decoration: _inputDecoration('Confirm New Password'),
                    ),
                    const SizedBox(height: 16),
                    _saveButton(
                      label: 'Change Password',
                      isSaving: isChangingPassword,
                      onPressed: _changePassword,
                    ),
                  ],
                ),
                _buildTeamSection(),
              ],
            ),
          ),
        ),
      ],
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
            ElevatedButton(onPressed: loadSettings, child: const Text('Retry')),
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
          'SETTINGS',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _buildLoadError()
          : RefreshIndicator(
              onRefresh: loadSettings,
              child: _buildSettingsContent(),
            ),
    );
  }
}
