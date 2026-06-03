# FocusFlight

A Flutter mobile application for flight exploration and tracking, built with GetX, Mapbox, and multi-language support (English & Lao).

---

## Features

- **Authentication** — Login, Register, Forgot Password
- **Onboarding** — Guided first-launch experience
- **Home Tabs** — Home, Explore, Search, Profile
- **Interactive Map** — Mapbox-powered flight map
- **Multi-language** — English (`en`) and Lao (`lo`) with runtime switching
- **Dark / Light Theme** — Persisted via GetStorage
- **Lottie Animations** — Smooth loading and splash screens
- **Responsive Layout** — Scaled with `sizer`

---

## Tech Stack

| Layer | Package |
|---|---|
| State & Navigation | `get` (GetX) |
| HTTP Client | `dio` + `pretty_dio_logger` |
| Local Storage | `get_storage` |
| Maps | `mapbox_maps_flutter` |
| Fonts | `google_fonts` (Poppins / Noto Sans Lao) |
| UI Assets | `flutter_svg`, `lottie`, `cached_network_image`, `shimmer` |
| Localization | `flutter_localizations`, `intl` |
| Permissions | `permission_handler` |
| Env Config | `flutter_dotenv` |

---

## Project Structure

```
lib/
├── main.dart
└── app/
    ├── bindings/       # GetX dependency injection
    ├── config/         # App environment (AppEnv)
    ├── controllers/    # Auth, Home, Locale, Theme
    ├── models/         # Data models
    ├── repositories/   # Data layer
    ├── routes/         # AppRoutes & AppPages
    ├── services/       # API client, response, exception handling
    ├── utils/          # Colors, theme, translations, resources
    ├── views/          # Screens (auth, home, onboarding, splash)
    └── widgets/        # Reusable UI components
```

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.1`
- Dart SDK (bundled with Flutter)
- A [Mapbox](https://www.mapbox.com/) account and public access token

### Setup

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd visual_focusflight
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**

   Create a `.env` file at the project root:
   ```env
   MAPBOX_TOKEN=your_mapbox_public_token
   BASE_URL=https://your-api-base-url.com
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

---

## Localization

Translation files are in `assets/translations/`. The app supports:

| Language | Code |
|---|---|
| English | `en_US` |
| Lao | `lo_LA` |

Language preference is stored locally and can be changed at runtime via the language toggle.

---

## Environment Variables

| Key | Description |
|---|---|
| `MAPBOX_TOKEN` | Mapbox public access token |
| `BASE_URL` | Backend API base URL |

> **Note:** The `.env` file is listed in `.gitignore` and bundled as a Flutter asset. Never commit secrets to version control.

---

## Scripts

```bash
flutter run              # Run on connected device/emulator
flutter build apk        # Build Android APK
flutter build ios        # Build iOS (macOS required)
flutter test             # Run unit tests
flutter analyze          # Static analysis
```
