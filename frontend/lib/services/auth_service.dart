import 'api_service.dart';
import 'token_service.dart';
import '../config/api_config.dart';

class AuthService {
  static Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String businessName,
    required String businessType,
    String? phone,
  }) async {
    await ApiService.post(ApiConfig.registerEndpoint, {
      'fullName': fullName,
      'email': email,
      'password': password,
      'businessName': businessName,
      'businessType': businessType,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await ApiService.post(ApiConfig.loginEndpoint, {
      'email': email,
      'password': password,
    });

    final data = Map<String, dynamic>.from(response['data']);

    final token = data['token'];

    if (token == null || token.toString().isEmpty) {
      throw Exception('Login succeeded but no token was returned');
    }

    final user = Map<String, dynamic>.from(data['user']);

    final memberships = List<Map<String, dynamic>>.from(
      user['memberships'] ?? [],
    );

    final activeMemberships = memberships
        .where((membership) => membership['status'] == 'active')
        .toList();

    if (activeMemberships.isEmpty) {
      throw Exception('No active business membership found');
    }

    final businessId = activeMemberships.first['business']?.toString();

    if (businessId == null || businessId.isEmpty) {
      throw Exception('No business is linked to this account');
    }

    await TokenService.saveToken(token);
    await TokenService.saveBusinessId(businessId);

    return data;
  }

  static Future<void> logout() async {
    await TokenService.deleteToken();
    await TokenService.deleteBusinessId();
  }
}
