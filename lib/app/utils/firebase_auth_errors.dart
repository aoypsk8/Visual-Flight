import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

/// แปลง FirebaseAuthException เป็นข้อความ i18n สำหรับ UI
String firebaseAuthErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'error_invalid_credentials'.tr;
      case 'email-already-in-use':
        return 'error_email_in_use'.tr;
      case 'weak-password':
        return 'valid_password_reg'.tr;
      case 'invalid-email':
      case 'missing-email':
        return 'valid_email'.tr;
      case 'user-disabled':
        return 'error_user_disabled'.tr;
      case 'too-many-requests':
        return 'error_too_many_requests'.tr;
      case 'operation-not-allowed':
        return 'error_auth_not_enabled'.tr;
      case 'requires-recent-login':
        return 'error_requires_recent_login'.tr;
      default:
        return 'error_generic'.tr;
    }
  }
  return 'error_generic'.tr;
}
