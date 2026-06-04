import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/common.dart';

class ForgotPasswordView extends StatelessWidget {
  const ForgotPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AuthController.to;

    return LocaleReactive(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.surf1,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Stack(
                children: [
                  AppAmberBlob(
                    x: 20.w,
                    y: -60,
                    radius: 18.w,
                    opacity: 0.06,
                  ),
                  AppAmberBlob(
                    x: 80.w,
                    y: 70.h,
                    radius: 16.w,
                    opacity: 0.04,
                  ),
                ],
              ),
              SafeArea(
                child: Form(
                  key: ctrl.forgotFormKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 6.5.w),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                _ForgotHeader(onBack: ctrl.backFromForgot),
                                const SizedBox(height: 28),
                                const AppLogo(
                                  size: 28,
                                  showLabel: true,
                                  bordered: true,
                                ),
                                const SizedBox(height: 32),
                                Obx(() {
                                  if (ctrl.forgotEmailSent.value) {
                                    return _ForgotSuccessBody(ctrl: ctrl);
                                  }
                                  return _ForgotFormBody(ctrl: ctrl);
                                }),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForgotHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _ForgotHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surf3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hair2),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.tx2,
              size: 16,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => AppLanguageSheet.show(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surf3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hair),
            ),
            child: const Icon(
              Icons.language_rounded,
              color: AppColors.tx2,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _ForgotFormBody extends StatelessWidget {
  final AuthController ctrl;

  const _ForgotFormBody({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.headline('forgot_password_title'.tr),
          const SizedBox(height: 10),
          AppText.body('forgot_password_subtitle'.tr),
          const SizedBox(height: 36),
          AppTextField(
            label: 'lbl_email'.tr,
            hint: 'hint_email'.tr,
            icon: Icons.mail_outline_rounded,
            controller: ctrl.emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => ctrl.requestPasswordReset(),
            validator: _emailValidator,
          ),
          const SizedBox(height: 8),
          Obx(
            () => ctrl.forgotErrorMsg.value.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: AppText.caption(
                      ctrl.forgotErrorMsg.value,
                      color: Colors.redAccent,
                      maxLines: 3,
                    ),
                  ),
          ),
          const Spacer(),
          Obx(
            () => AppPrimaryButton(
              label: 'btn_send_reset_link'.tr,
              loading: ctrl.forgotIsLoading.value,
              onTap: ctrl.requestPasswordReset,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: ctrl.backFromForgot,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: AppText(
                  'back_to_sign_in'.tr,
                  color: AppColors.tx2,
                  fontSize: 12,
                  underline: true,
                  underlineColor: AppColors.tx2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ForgotSuccessBody extends StatelessWidget {
  final AuthController ctrl;

  const _ForgotSuccessBody({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final email = ctrl.emailCtrl.text.trim();

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.amberSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hair2),
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: AppColors.amber,
              size: 26,
            ),
          ),
          const SizedBox(height: 24),
          AppText.headline('forgot_password_sent_title'.tr),
          const SizedBox(height: 10),
          AppText.body(
            'forgot_password_sent_body'.trParams({'email': email}),
          ),
          const Spacer(),
          AppPrimaryButton(
            label: 'back_to_sign_in'.tr,
            onTap: ctrl.backFromForgot,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

String? _emailValidator(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty || !v.contains('@') || !v.contains('.')) {
    return 'valid_email'.tr;
  }
  return null;
}
