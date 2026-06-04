import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/app_local_storage.dart';
import 'package:lottie/lottie.dart';

import '../../routes/app_routes.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_resources.dart';
import '../../widgets/common/app_text.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  static const _fallbackDuration = Duration(milliseconds: 3500);
  static const _postCompleteDelay = Duration(milliseconds: 800);
  late final AnimationController _lottieCtrl;
  bool _isComplete = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _lottieCtrl = AnimationController(vsync: this);
    Future<void>.delayed(_fallbackDuration, () {
      if (mounted && !_navigated) {
        _goToLogin();
      }
    });
  }

  @override
  void dispose() {
    _lottieCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLottieLoaded(LottieComposition composition) async {
    if (!mounted || _navigated) return;
    _lottieCtrl
      ..duration = composition.duration
      ..reset();
    await _lottieCtrl.forward();
    if (!mounted || _navigated) return;
    setState(() => _isComplete = true);
    await Future<void>.delayed(_postCompleteDelay);
    if (mounted && !_navigated) {
      _goToLogin();
    }
  }

 
  void _goToLogin() {
    _navigated = true;
    final done = AppLocalStorage.readBool('onboarding_done') ?? false;
    Get.offNamed(done ? AppRoutes.login : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surf1,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.90,
              height: MediaQuery.of(context).size.height * 0.68,
              child: Lottie.asset(
                AppAnimations.businessmanRocket,
                controller: _lottieCtrl,
                fit: BoxFit.contain,
                repeat: false,
                onLoaded: _handleLottieLoaded,
                errorBuilder: (context, error, _) {
                  return const Center(
                    child: Icon(
                      AppIcons.lottieFallback,
                      color: AppColors.amber,
                      size: 64,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(14),
                    Colors.black.withAlpha(92),
                  ],
                ),
              ),
            ),
          ),
          // Adds a subtle amber light layer to make the image look more premium
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.7),
                  radius: 1.1,
                  colors: [
                    AppColors.amber.withAlpha(26),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _lottieCtrl,
                    builder: (context, _) {
                      final value = _lottieCtrl.value.clamp(0.0, 1.0);
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: SizedBox(
                              height: 4,
                              child: Stack(
                                children: [
                                  Container(color: Colors.white.withAlpha(36)),
                                  FractionallySizedBox(
                                    widthFactor: value,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFFBC975), AppColors.amber],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AppText(
                            _isComplete ? 'Completed' : 'Loading ${(value * 100).round()}%',
                            color: _isComplete ? AppColors.tx1 : AppColors.tx2,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

