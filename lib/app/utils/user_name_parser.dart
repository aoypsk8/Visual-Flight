import 'package:get/get.dart';

/// แยกชื่อเต็มจาก Firebase / ฟอร์มสมัคร เป็น first / last
class ParsedUserName {
  const ParsedUserName({
    required this.fullName,
    required this.firstName,
    required this.lastName,
  });

  final String fullName;
  final String firstName;
  final String lastName;
}

ParsedUserName parseUserDisplayName({
  String? displayName,
  String? email,
}) {
  final trimmed = displayName?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return ParsedUserName(
        fullName: trimmed,
        firstName: parts.first,
        lastName: '',
      );
    }
    return ParsedUserName(
      fullName: trimmed,
      firstName: parts.first,
      lastName: parts.sublist(1).join(' '),
    );
  }

  final fallback = _fallbackFromEmail(email);
  return ParsedUserName(
    fullName: fallback,
    firstName: fallback,
    lastName: '',
  );
}

String _fallbackFromEmail(String? email) {
  if (email == null || !email.contains('@')) return 'traveler_default'.tr;
  final local = email.split('@').first;
  return local.isEmpty ? 'traveler_default'.tr : local;
}
