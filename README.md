# Local Vyapari Vendor App

A production-grade Flutter application for vendors to manage their digital storefront, products, offers, and inventory.

## Architecture Highlights
- **Clean Architecture**: Separation of concerns across UI, Domain, Data, and Core network layers.
- **State Management**: `flutter_riverpod` for scalable, testable, and reactive state.
- **Networking**: `dio` with robust interceptor configurations for JWT.
- **Models**: `freezed` & `json_serializable` for robust immutability and JSON mapping.
- **UI System**: Reusable foundational widgets (`PrimaryButton`, `CustomTextField`), beautiful `AppTheme`, and consistent `AppColors`.

## Getting Started

### 1. Install Dependencies
Run the following command to fetch all packages:
```bash
flutter pub get
```

### 2. Generate Freezed Models
Since we use Freezed for data models to ensure type safety and immutability, you must generate the code files (`*.freezed.dart` and `*.g.dart`) before running the app.
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Run the App
```bash
flutter run
```

## Folder Structure
- `lib/core/`: Application-wide configurations, theming, and network clients.
- `lib/data/`: Models and Repositories for backend communication.
- `lib/domain/`: Riverpod providers and business logic.
- `lib/ui/`: Presentation layer, split into common reusable widgets and specific feature screens.
