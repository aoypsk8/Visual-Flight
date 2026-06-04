import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_model.dart';
import '../routes/auth_redirect.dart';
import '../utils/user_name_parser.dart';
import 'app_local_storage.dart';

/// Auth ผ่าน Firebase — sync เป็น [UserModel] สำหรับ UI และ API Bearer token
class AuthService extends GetxService {
  static AuthService get to => Get.find();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final user = Rxn<UserModel>();
  bool get isLoggedIn => user.value != null;

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
    _firebaseAuth.authStateChanges().listen(_onFirebaseUserChanged);
  }

  void _onFirebaseUserChanged(User? fbUser) async {
    if (fbUser == null) {
      final hadUser = user.value != null;
      _clearSession();
      if (hadUser) AuthRedirect.toLoginIfNeeded();
      return;
    }
    await _persistFromFirebaseUser(fbUser);
  }

  void _restoreSession() {
    final raw = AppLocalStorage.readJsonMap(_userKey);
    if (raw != null) {
      user.value = UserModel.fromJson(Map<String, dynamic>.from(raw));
    }
    final current = _firebaseAuth.currentUser;
    if (current != null) {
      _persistFromFirebaseUser(current);
    }
  }

  // ── Email / Password ───────────────────────────────────────────────────────

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final cred = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _persistFromFirebaseUser(cred.user!);
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.updateDisplayName(name.trim());
    await cred.user!.reload();
    return _persistFromFirebaseUser(_firebaseAuth.currentUser!);
  }

  Future<void> forgotPassword({required String email}) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Email is required',
      );
    }
    await _firebaseAuth.sendPasswordResetEmail(email: trimmed);
  }

  // ── Social ─────────────────────────────────────────────────────────────────

  Future<UserModel?> loginWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _firebaseAuth.signInWithCredential(credential);
    final fbUser = cred.user!;
    final googleName = googleUser.displayName?.trim();
    if ((fbUser.displayName == null || fbUser.displayName!.trim().isEmpty) &&
        googleName != null &&
        googleName.isNotEmpty) {
      await fbUser.updateDisplayName(googleName);
      await fbUser.reload();
      return _persistFromFirebaseUser(_firebaseAuth.currentUser!);
    }
    return _persistFromFirebaseUser(fbUser);
  }

  Future<UserModel> loginWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCred = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauth = OAuthProvider('apple.com').credential(
      idToken: appleCred.identityToken,
      rawNonce: rawNonce,
    );
    final userCred = await _firebaseAuth.signInWithCredential(oauth);

    final displayName = [
      appleCred.givenName,
      appleCred.familyName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');

    if (displayName.isNotEmpty &&
        (userCred.user?.displayName == null ||
            userCred.user!.displayName!.isEmpty)) {
      await userCred.user!.updateDisplayName(displayName);
      await userCred.user!.reload();
    }

    return _persistFromFirebaseUser(_firebaseAuth.currentUser!);
  }

  // ── Profile ──────────────────────────────────────────────────────────────────

  Future<void> updateDisplayName(String name) async {
    final u = _firebaseAuth.currentUser;
    if (u == null) return;
    await u.updateDisplayName(name.trim());
    await u.reload();
    await _persistFromFirebaseUser(_firebaseAuth.currentUser!);
  }

  Future<void> updatePassword(String newPassword) async {
    await _firebaseAuth.currentUser!.updatePassword(newPassword);
  }

  Future<void> sendEmailVerification() async {
    await _firebaseAuth.currentUser?.sendEmailVerification();
  }

  // ── Session ──────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (_) {}
    _clearSession();
    AuthRedirect.toLoginIfNeeded();
  }

  String? get token => AppLocalStorage.readString(_tokenKey);

  Future<UserModel> _persistFromFirebaseUser(User fbUser) async {
    final idToken = await fbUser.getIdToken();
    final parsed = parseUserDisplayName(
      displayName: fbUser.displayName,
      email: fbUser.email,
    );
    final model = UserModel(
      id: fbUser.uid,
      name: parsed.fullName,
      firstName: parsed.firstName,
      lastName: parsed.lastName,
      email: fbUser.email ?? '',
      photoUrl: fbUser.photoURL,
      token: idToken,
    );
    user.value = model;
    if (idToken != null) {
      AppLocalStorage.writeString(_tokenKey, idToken);
    }
    AppLocalStorage.writeJsonMap(_userKey, model.toJson());
    return model;
  }

  void _clearSession() {
    user.value = null;
    AppLocalStorage.remove(_tokenKey);
    AppLocalStorage.remove(_userKey);
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
