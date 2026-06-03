import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    show MapboxOptions;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'app/bindings/initial_binding.dart';
import 'app/config/app_env.dart';
import 'app/controllers/locale_controller.dart';
import 'app/controllers/theme_controller.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/utils/app_colors.dart';
import 'app/utils/app_theme.dart';
import 'app/utils/translations/app_translations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  MapboxOptions.setAccessToken(AppEnv.mapboxToken);
  await GetStorage.init();
  await AppTranslations.load();
  Get.put(LocaleController(), permanent: true);
  Get.put(ThemeController(), permanent: true);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surf1,
  ));

  runApp(const FocusFlightApp());
}

class FocusFlightApp extends StatelessWidget {
  const FocusFlightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final locale   = LocaleController.to.current.value;
      final isDark   = ThemeController.to.isDark.value;
      final isLao    = locale.languageCode == 'lo';

      final darkTextTheme = _textTheme(
        base: ThemeData.dark().textTheme.apply(
              bodyColor:    AppColors.tx1,
              displayColor: AppColors.tx1,
            ),
        isLao: isLao,
      );
      final lightTextTheme = _textTheme(
        base: ThemeData.light().textTheme.apply(
              bodyColor:    const Color(0xFF0A0B0D),
              displayColor: const Color(0xFF0A0B0D),
            ),
        isLao: isLao,
      );

      return Sizer(
        builder: (context, orientation, screenType) => GetMaterialApp(
          title: 'FocusFlight',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LocaleController.supported
              .map((l) => Locale(l.code, l.country))
              .toList(),

          initialBinding: InitialBinding(),

          translations: AppTranslations(),
          locale: locale,
          fallbackLocale: const Locale('en', 'US'),
          localeListResolutionCallback: (deviceLocales, supported) {
            final app = LocaleController.to.current.value;
            for (final s in supported) {
              if (s.languageCode == app.languageCode &&
                  (s.countryCode == app.countryCode ||
                      app.countryCode == null)) {
                return s;
              }
            }
            return const Locale('en', 'US');
          },

          // ── Themes ──────────────────────────────────────────────────
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.surf1,
            colorScheme: const ColorScheme.dark(
              primary: AppColors.amber,
              surface: AppColors.surf1,
            ),
            extensions: const [AppTheme.dark],
            fontFamily: isLao
                ? GoogleFonts.notoSansLao().fontFamily
                : GoogleFonts.poppins().fontFamily,
            textTheme: darkTextTheme,
            useMaterial3: true,
          ),

          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF2F2F7),
            colorScheme: const ColorScheme.light(
              primary: AppColors.amber,
              surface: Color(0xFFF2F2F7),
            ),
            extensions: const [AppTheme.light],
            fontFamily: isLao
                ? GoogleFonts.notoSansLao().fontFamily
                : GoogleFonts.poppins().fontFamily,
            textTheme: lightTextTheme,
            useMaterial3: true,
          ),

          // ── Navigation ───────────────────────────────────────────────
          initialRoute: AppRoutes.splash,
          getPages: AppPages.pages,
        ),
      );
    });
  }

  TextTheme _textTheme({required TextTheme base, required bool isLao}) =>
      isLao
          ? GoogleFonts.notoSansLaoTextTheme(base)
          : GoogleFonts.poppinsTextTheme(base);
}
