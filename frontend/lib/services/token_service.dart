import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Save JWT token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  // Retrieve JWT token
  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // Delete JWT token during logout
  static Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }

  static Future<void> saveBusinessId(String businessId) async {
    await _storage.write(key: 'business_id', value: businessId);
  }

  static Future<String?> getBusinessId() async {
    return await _storage.read(key: 'business_id');
  }

  static Future<void> deleteBusinessId() async {
    await _storage.delete(key: 'business_id');
  }
}
