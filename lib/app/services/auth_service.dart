import 'package:get/get.dart';
import 'app_local_storage.dart';
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
    final raw = AppLocalStorage.readJsonMap(_userKey);
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

  String? get token => AppLocalStorage.readString(_tokenKey);

  // ── Private helpers ──────────────────────────────────────────────────────────

  void _saveSession(UserModel u) {
    user.value = u;
    if (u.token != null) {
      AppLocalStorage.writeString(_tokenKey, u.token!);
    }
    AppLocalStorage.writeJsonMap(_userKey, u.toJson());
  }

  void _clearSession() {
    user.value = null;
    AppLocalStorage.remove(_tokenKey);
    AppLocalStorage.remove(_userKey);
  }
}
