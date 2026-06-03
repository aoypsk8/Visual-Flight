import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_resources.dart';
import '../../widgets/common/common.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

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
              // ── Ambient blobs ───────────────────────────────────────────
              Stack(children: [
                AppAmberBlob(
                  x: 25.w,
                  y: -80,
                  radius: 20.w,
                  opacity: 0.05,
                ),
                AppAmberBlob(
                  x: 75.w,
                  y: 85.h,
                  radius: 20.w,
                  opacity: 0.05,
                ),
              ]),

              // ── Content ─────────────────────────────────────────────────
              SafeArea(
                child: Form(
                  key: ctrl.loginFormKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 6.5.w),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: 100.h -
                            MediaQuery.of(context).padding.top -
                            MediaQuery.of(context).padding.bottom,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 56),

                            // ── Brand + language toggle ──────────────────
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.amberSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const AppText.label('FocusFlight',
                                      color: AppColors.amber),
                                ),
                                const Spacer(),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => AppLanguageSheet.show(context),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.surf3,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppColors.hair, width: 1),
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

                            const SizedBox(height: 32),

                            // ── Headline ─────────────────────────────────
                            AppText.headline('welcome_back'.tr),
                            const SizedBox(height: 10),
                            AppText.body('sign_in_subtitle'.tr),

                            const SizedBox(height: 36),

                            // ── Email ────────────────────────────────────
                            AppTextField(
                              label: 'lbl_email'.tr,
                              hint: 'hint_email'.tr,
                              icon: Icons.mail_outline_rounded,
                              controller: ctrl.emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              // validator: (v) => (v == null || !v.contains('@'))
                              //     ? 'valid_email'.tr
                              //     : null,
                            ),

                            const SizedBox(height: 20),

                            // ── Password ─────────────────────────────────
                            AppTextField(
                              label: 'lbl_password'.tr,
                              hint: 'hint_password'.tr,
                              icon: Icons.lock_outline_rounded,
                              controller: ctrl.passwordCtrl,
                              obscure: true,
                              textInputAction: TextInputAction.done,
                              // validator: (v) =>
                              //     (v == null || v.length < 6)
                              //         ? 'valid_password'.tr
                              //         : null,
                            ),

                            const SizedBox(height: 14),

                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: ctrl.goToForgotPassword,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child:
                                      AppText.caption('forgot_password'.tr),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // ── Error message ────────────────────────────
                            Obx(() => ctrl.errorMsg.value.isEmpty
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: AppText.caption(
                                      ctrl.errorMsg.value,
                                      color: Colors.redAccent,
                                    ),
                                  )),

                            const SizedBox(height: 16),

                            // ── Sign in button ───────────────────────────
                            Obx(() => AppPrimaryButton(
                                  label: 'btn_sign_in'.tr,
                                  loading: ctrl.isLoading.value,
                                  onTap: ctrl.signIn,
                                )),

                            const SizedBox(height: 20),
                            AppOrDivider(label: 'or_continue_with'.tr),
                            const SizedBox(height: 16),

                            // ── Social buttons ───────────────────────────
                            Row(children: [
                              Expanded(
                                child: AppSocialButton(
                                  iconAsset: AppIcons.google,
                                  label: 'Google',
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AppSocialButton(
                                  iconAsset: AppIcons.apple,
                                  label: 'Apple',
                                  onTap: () {},
                                ),
                              ),
                            ]),

                            const Spacer(),

                            // ── Register link ────────────────────────────
                            Center(
                              child: GestureDetector(
                                onTap: ctrl.goToRegister,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: RichText(
                                    text: TextSpan(
                                      text: '${'new_here'.tr}  ',
                                      style: TextStyle(
                                        color: AppColors.tx3,
                                        fontSize: 14,
                                        fontFamily:
                                            AppText.fontFamilyOf(context),
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'go_create_account'.tr,
                                          style: const TextStyle(
                                            color: AppColors.tx1,
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
