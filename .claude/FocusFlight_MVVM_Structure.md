# ✈️ Visual FocusFlight — Flutter MVVM + GetX Project Structure

> **MVVM** (Model · View · ViewModel) architecture powered by **GetX**  
> Project: `visual_focusflight`

---

## 📁 Root Structure

```
visual_focusflight/
├── android/
├── ios/
├── assets/
│   ├── images/
│   ├── icons/
│   ├── animations/          # Lottie / Rive files
│   └── fonts/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── bindings/
│   │   ├── controllers/     # ViewModels (GetX Controllers)
│   │   ├── models/
│   │   ├── views/
│   │   ├── widgets/
│   │   ├── routes/
│   │   ├── services/
│   │   ├── repositories/
│   │   └── utils/
├── test/
├── pubspec.yaml
└── README.md
```

---

## 📂 Detailed `lib/` Structure

```
lib/
├── main.dart                          # App entry point
│
└── app/
    │
    ├── bindings/                      # Dependency injection (GetX Bindings)
    │   ├── initial_binding.dart       # App-wide services
    │   ├── home_binding.dart
    │   ├── flight_binding.dart
    │   ├── search_binding.dart
    │   ├── booking_binding.dart
    │   ├── profile_binding.dart
    │   └── auth_binding.dart
    │
    ├── models/                        # M — Data / Domain Models
    │   ├── flight_model.dart
    │   ├── airport_model.dart
    │   ├── booking_model.dart
    │   ├── passenger_model.dart
    │   ├── seat_model.dart
    │   ├── user_model.dart
    │   └── filter_model.dart
    │
    ├── controllers/                   # VM — ViewModels (GetxController)
    │   ├── home_controller.dart
    │   ├── flight_controller.dart
    │   ├── search_controller.dart
    │   ├── booking_controller.dart
    │   ├── seat_controller.dart
    │   ├── profile_controller.dart
    │   └── auth_controller.dart
    │
    ├── views/                         # V — UI Screens
    │   ├── splash/
    │   │   └── splash_view.dart
    │   ├── auth/
    │   │   ├── login_view.dart
    │   │   └── register_view.dart
    │   ├── home/
    │   │   └── home_view.dart
    │   ├── search/
    │   │   ├── search_view.dart
    │   │   └── search_results_view.dart
    │   ├── flight/
    │   │   ├── flight_detail_view.dart
    │   │   └── flight_tracker_view.dart
    │   ├── booking/
    │   │   ├── booking_view.dart
    │   │   ├── seat_selection_view.dart
    │   │   └── booking_confirm_view.dart
    │   ├── profile/
    │   │   └── profile_view.dart
    │   └── settings/
    │       └── settings_view.dart
    │
    ├── widgets/                       # Reusable UI Components
    │   ├── common/
    │   │   ├── custom_button.dart
    │   │   ├── custom_text_field.dart
    │   │   ├── loading_overlay.dart
    │   │   └── error_widget.dart
    │   ├── flight/
    │   │   ├── flight_card.dart
    │   │   ├── flight_route_banner.dart
    │   │   └── flight_status_badge.dart
    │   └── booking/
    │       ├── seat_grid.dart
    │       └── passenger_form.dart
    │
    ├── routes/                        # Navigation
    │   ├── app_routes.dart            # Route name constants
    │   └── app_pages.dart             # GetPage definitions
    │
    ├── services/                      # External services (API, storage)
    │   ├── api_service.dart           # HTTP client (Dio / GetConnect)
    │   ├── auth_service.dart
    │   ├── storage_service.dart       # SharedPreferences / GetStorage
    │   └── notification_service.dart
    │
    ├── repositories/                  # Data abstraction layer
    │   ├── flight_repository.dart
    │   ├── booking_repository.dart
    │   └── user_repository.dart
    │
    └── utils/                         # Helpers & Constants
        ├── app_theme.dart
        ├── app_colors.dart
        ├── app_strings.dart
        ├── app_constants.dart
        ├── validators.dart
        └── date_formatter.dart
```

---

## 🧱 MVVM Layer Responsibilities

| Layer | Folder | Role |
|---|---|---|
| **Model** | `models/` | Data classes, JSON serialization, domain entities |
| **View** | `views/` + `widgets/` | UI only — uses `Obx()` / `GetBuilder` to react to state |
| **ViewModel** | `controllers/` | Business logic, state management via `.obs`, calls repositories |
| **Repository** | `repositories/` | Abstracts data sources (API / local) from controllers |
| **Service** | `services/` | Low-level operations: HTTP, storage, push notifications |
| **Binding** | `bindings/` | Injects controllers/services per route via `GetX` |

---

## 🛣️ Routes — `app_routes.dart`

```dart
abstract class AppRoutes {
  static const splash       = '/';
  static const login        = '/login';
  static const register     = '/register';
  static const home         = '/home';
  static const search       = '/search';
  static const searchResult = '/search/results';
  static const flightDetail = '/flight/detail';
  static const flightTrack  = '/flight/tracker';
  static const booking      = '/booking';
  static const seatSelect   = '/booking/seats';
  static const bookingDone  = '/booking/confirm';
  static const profile      = '/profile';
  static const settings     = '/settings';
}
```

---

## ⚙️ Key Dependencies — `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management & Navigation
  get: ^4.6.6

  # Networking
  dio: ^5.4.3+1
  pretty_dio_logger: ^1.3.1

  # Local Storage
  get_storage: ^2.1.1

  # UI & Animations
  google_fonts: ^6.2.1
  flutter_svg: ^2.0.10+1
  lottie: ^3.1.0
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0

  # Utils
  intl: ^0.19.0
  equatable: ^2.0.5
  json_annotation: ^4.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.9
  json_serializable: ^6.8.0
```

---

## 🔁 MVVM Data Flow

```
View (UI)
  │  triggers action (button tap, input)
  ▼
Controller / ViewModel (GetxController)
  │  calls repository method
  ▼
Repository
  │  calls service (API or local storage)
  ▼
Service (ApiService / StorageService)
  │  returns raw data
  ▼
Repository
  │  maps to Model
  ▼
Controller
  │  updates .obs reactive state
  ▼
View (UI)
  └─ Obx(() => ...) rebuilds automatically ✅
```

---

## 📋 Screen Map

| Screen | Route | Controller | Description |
|---|---|---|---|
| Splash | `/` | — | Animated logo, auth check |
| Login | `/login` | `AuthController` | Email / SSO sign in |
| Register | `/register` | `AuthController` | New user registration |
| Home | `/home` | `HomeController` | Featured flights, quick search |
| Search | `/search` | `SearchController` | Departure / destination / date picker |
| Results | `/search/results` | `SearchController` | Filtered flight list |
| Flight Detail | `/flight/detail` | `FlightController` | Full flight info, pricing |
| Flight Tracker | `/flight/tracker` | `FlightController` | Live flight map & status |
| Booking | `/booking` | `BookingController` | Passenger info form |
| Seat Select | `/booking/seats` | `SeatController` | Visual seat grid |
| Confirmation | `/booking/confirm` | `BookingController` | Summary + payment |
| Profile | `/profile` | `ProfileController` | User info, trip history |
| Settings | `/settings` | `SettingsController` | Theme, language, notifications |

---

## 🏷️ Naming Conventions

| Type | Convention | Example |
|---|---|---|
| Files | `snake_case.dart` | `flight_model.dart` |
| Classes | `PascalCase` | `FlightController` |
| Variables | `camelCase` | `flightList` |
| Observables | `_private.obs` | `_flights = <FlightModel>[].obs` |
| Routes | `SCREAMING_SNAKE` constant | `AppRoutes.flightDetail` |
| Assets | `snake_case` | `plane_icon.svg` |

---

## ✅ GetX Controller Template

```dart
// lib/app/controllers/flight_controller.dart

import 'package:get/get.dart';
import '../models/flight_model.dart';
import '../repositories/flight_repository.dart';

class FlightController extends GetxController {
  final FlightRepository _repo = Get.find();

  // State
  final _flights    = <FlightModel>[].obs;
  final _selected   = Rxn<FlightModel>();
  final _isLoading  = false.obs;
  final _error      = ''.obs;

  // Getters
  List<FlightModel> get flights   => _flights;
  FlightModel?      get selected  => _selected.value;
  bool              get isLoading => _isLoading.value;
  String            get error     => _error.value;

  @override
  void onInit() {
    super.onInit();
    fetchFlights();
  }

  Future<void> fetchFlights() async {
    _isLoading.value = true;
    _error.value = '';
    try {
      final result = await _repo.getFlights();
      _flights.assignAll(result);
    } catch (e) {
      _error.value = e.toString();
      Get.snackbar('Error', 'Could not load flights');
    } finally {
      _isLoading.value = false;
    }
  }

  void selectFlight(FlightModel flight) {
    _selected.value = flight;
    Get.toNamed(AppRoutes.flightDetail);
  }
}
```

---

*Generated for **Visual FocusFlight** · Flutter + GetX MVVM · 2026*
