import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';
import '../services/auth_service.dart';

/// Shared state for the login, register, and forgot-password screens
class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final _auth = AuthService.to;

  // ── Form fields ────────────────────────────────────────────────────────────
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  final loginFormKey = GlobalKey<FormState>();
  final registerFormKey = GlobalKey<FormState>();
  final forgotFormKey = GlobalKey<FormState>();

  // ── Shared / login-register ────────────────────────────────────────────────
  final isLoading = false.obs;
  final errorMsg = ''.obs;

  // ── Forgot password ────────────────────────────────────────────────────────
  final forgotIsLoading = false.obs;
  final forgotErrorMsg = ''.obs;
  final forgotEmailSent = false.obs;

  @override
  void onClose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.onClose();
  }

  void _clearError() => errorMsg.value = '';

  void _clearForgotState() {
    forgotErrorMsg.value = '';
    forgotEmailSent.value = false;
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<void> signIn() async {
    _clearError();
    if (!loginFormKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      // await _auth.login(
      //   email: emailCtrl.text.trim(),
      //   password: passwordCtrl.text,
      // );
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void goToRegister() {
    _clearError();
    Get.toNamed(AppRoutes.register);
  }

  void goToForgotPassword() {
    _clearError();
    _clearForgotState();
    Get.toNamed(AppRoutes.forgotPassword);
  }

  // ── Register ─────────────────────────────────────────────────────────────

  Future<void> register() async {
    _clearError();
    if (!registerFormKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      await _auth.register(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
      );
      Get.offAllNamed(AppRoutes.login); // TODO: change to home route when ready
    } catch (e) {
      errorMsg.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void goToSignIn() {
    _clearError();
    Get.back();
  }

  // ── Forgot password ────────────────────────────────────────────────────────

  Future<void> requestPasswordReset() async {
    _clearForgotState();
    if (!forgotFormKey.currentState!.validate()) return;

    forgotIsLoading.value = true;
    try {
      final email = emailCtrl.text.trim();
      await _auth.forgotPassword(email: email);
      forgotEmailSent.value = true;
    } catch (e) {
      forgotErrorMsg.value = e.toString();
    } finally {
      forgotIsLoading.value = false;
    }
  }

  void backFromForgot() {
    _clearForgotState();
    Get.back();
  }
}
