import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../utils/firebase_auth_errors.dart';

/// Login, register, forgot-password และ social sign-in (Firebase)
class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final _auth = AuthService.to;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  final loginFormKey = GlobalKey<FormState>();
  final registerFormKey = GlobalKey<FormState>();
  final forgotFormKey = GlobalKey<FormState>();

  final isLoading = false.obs;
  final errorMsg = ''.obs;

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

  Future<void> signIn() async {
    _clearError();
    if (!loginFormKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      await _auth.login(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
      );
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      errorMsg.value = firebaseAuthErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    _clearError();
    isLoading.value = true;
    try {
      final result = await _auth.loginWithGoogle();
      if (result != null) {
        Get.offAllNamed(AppRoutes.home);
      }
    } catch (e) {
      errorMsg.value = firebaseAuthErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithApple() async {
    _clearError();
    isLoading.value = true;
    try {
      await _auth.loginWithApple();
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      errorMsg.value = firebaseAuthErrorMessage(e);
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
      Get.offAllNamed(AppRoutes.home);
    } catch (e) {
      errorMsg.value = firebaseAuthErrorMessage(e);
    } finally {
      isLoading.value = false;
    }
  }

  void goToSignIn() {
    _clearError();
    Get.back();
  }

  Future<void> requestPasswordReset() async {
    _clearForgotState();
    if (!forgotFormKey.currentState!.validate()) return;

    forgotIsLoading.value = true;
    try {
      await _auth.forgotPassword(email: emailCtrl.text.trim());
      forgotEmailSent.value = true;
    } catch (e) {
      forgotErrorMsg.value = firebaseAuthErrorMessage(e);
    } finally {
      forgotIsLoading.value = false;
    }
  }

  void backFromForgot() {
    _clearForgotState();
    Get.back();
  }
}
