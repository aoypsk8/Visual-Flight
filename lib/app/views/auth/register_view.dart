import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/auth_features.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_resources.dart';
import '../../widgets/common/common.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AuthController.to;
    final size = MediaQuery.of(context).size;

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
                    x: size.width * 0.8,
                    y: size.height * 0.1,
                    radius: 200,
                    opacity: 0.11,
                  ),
                  AppAmberBlob(
                    x: size.width * 0.15,
                    y: size.height * 0.75,
                    radius: 160,
                    opacity: 0.08,
                  ),
                ],
              ),
              SafeArea(
                child: Form(
                  key: ctrl.registerFormKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            size.height -
                            MediaQuery.of(context).padding.top -
                            MediaQuery.of(context).padding.bottom,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: ctrl.goToSignIn,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.surf3,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.hair2,
                                        width: 1,
                                      ),
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
                                      border: Border.all(
                                        color: AppColors.hair,
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.language_rounded,
                                      color: AppColors.tx2,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            const AppLogo(
                              size: 28,
                              showLabel: true,
                              bordered: true,
                            ),
                            const SizedBox(height: 28),
                            AppText.headline('create_account_title'.tr),
                            const SizedBox(height: 10),
                            AppText.body('create_account_subtitle'.tr),
                            const SizedBox(height: 32),
                            AppTextField(
                              label: 'lbl_full_name'.tr,
                              hint: 'hint_full_name'.tr,
                              icon: Icons.person_outline_rounded,
                              controller: ctrl.nameCtrl,
                              keyboardType: TextInputType.name,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  (v == null || v.trim().length < 2)
                                  ? 'valid_name'.tr
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            AppTextField(
                              label: 'lbl_email'.tr,
                              hint: 'hint_email'.tr,
                              icon: Icons.mail_outline_rounded,
                              controller: ctrl.emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'valid_email'.tr
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            AppTextField(
                              label: 'lbl_password'.tr,
                              hint: 'hint_password_reg'.tr,
                              icon: Icons.lock_outline_rounded,
                              controller: ctrl.passwordCtrl,
                              obscure: true,
                              textInputAction: TextInputAction.done,
                              validator: (v) => (v == null || v.length < 8)
                                  ? 'valid_password_reg'.tr
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            AppText.caption('password_hint_text'.tr),
                            const SizedBox(height: 8),
                            Obx(
                              () => ctrl.errorMsg.value.isEmpty
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: AppText.caption(
                                        ctrl.errorMsg.value,
                                        color: Colors.redAccent,
                                        maxLines: 2,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            Obx(
                              () => AppPrimaryButton(
                                label: 'btn_create_account'.tr,
                                loading: ctrl.isLoading.value,
                                onTap: ctrl.register,
                              ),
                            ),
                            const SizedBox(height: 20),
                            AppOrDivider(label: 'or_continue_with'.tr),
                            const SizedBox(height: 16),
                            Obx(
                              () => AppSocialButton(
                                iconAsset: AppIcons.google,
                                label: 'Google',
                                onTap: ctrl.isLoading.value
                                    ? null
                                    : ctrl.signInWithGoogle,
                              ),
                            ),
                            if (AuthFeatures.appleSignInEnabled) ...[
                              const SizedBox(height: 10),
                              Obx(
                                () => AppSocialButton(
                                  iconAsset: AppIcons.apple,
                                  label: 'Apple',
                                  onTap: ctrl.isLoading.value
                                      ? null
                                      : ctrl.signInWithApple,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Center(
                              child: GestureDetector(
                                onTap: ctrl.goToSignIn,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      text: '${'already_have_account'.tr}  ',
                                      style: AppText.styleOf(
                                        context,
                                        color: AppColors.tx3,
                                        fontSize: 14,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'go_sign_in'.tr,
                                          style: AppText.styleOf(
                                            context,
                                            color: AppColors.tx1,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
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
