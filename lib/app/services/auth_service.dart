import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import 'api/api_exception.dart';

// Sits between Controller and Repository.
// Owns token persistence and session state.
// Translates ApiException codes into readable tr-keys before rethrowing.
class AuthService extends GetxService {
  static AuthService get to => Get.find();

  static const _tokenKey = 'auth_token';
  static const _userKey  = 'auth_user';

  final AuthRepository _repo;
  final _box = GetStorage();

  final user = Rxn<UserModel>();
  bool get isLoggedIn => user.value != null;

  AuthService(this._repo);

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  void _restoreSession() {
    final raw = _box.read<Map?>(_userKey);
    if (raw != null) {
      user.value = UserModel.fromJson(Map<String, dynamic>.from(raw));
    }
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _repo.login(email: email, password: password);
      _saveSession(result);
      return result;
    } on ApiException {
      rethrow;
    }
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final result = await _repo.register(name: name, email: email, password: password);
      _saveSession(result);
      return result;
    } on ApiException {
      rethrow;
    }
  }

  Future<void> forgotPassword({required String email}) async {
    try {
      await _repo.forgotPassword(email: email);
    } on ApiException {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (_) {
      // best-effort — clear local session regardless of server response
    }
    _clearSession();
  }

  String? get token => _box.read<String>(_tokenKey);

  // ── Private helpers ──────────────────────────────────────────────────────────

  void _saveSession(UserModel u) {
    user.value = u;
    if (u.token != null) _box.write(_tokenKey, u.token);
    _box.write(_userKey, u.toJson());
  }

  void _clearSession() {
    user.value = null;
    _box.remove(_tokenKey);
    _box.remove(_userKey);
  }
}
