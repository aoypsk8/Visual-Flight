import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/locale_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LocaleReactive
//
// Forces rebuild when LocaleController.current changes
// (.tr text + widgets not directly bound to Localizations)
// ─────────────────────────────────────────────────────────────────────────────

class LocaleReactive extends StatelessWidget {
  final Widget Function(BuildContext context) builder;

  const LocaleReactive({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final _ = LocaleController.to.current.value;
      return builder(context);
    });
  }
}
