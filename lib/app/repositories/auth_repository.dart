import '../models/user_model.dart';
import '../services/api/api_client.dart';

class AuthRepository {
  final ApiClient _client;

  AuthRepository(this._client);

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.post<UserModel>(
      '/auth/login',
      data: {'email': email, 'password': password},
      fromJson: (json) => UserModel.fromJson(json as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _client.post<UserModel>(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
      fromJson: (json) => UserModel.fromJson(json as Map<String, dynamic>),
    );
    return res.data!;
  }

  Future<void> forgotPassword({required String email}) async {
    await _client.post<void>(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  Future<void> logout() async {
    await _client.post<void>('/auth/logout');
  }
}
