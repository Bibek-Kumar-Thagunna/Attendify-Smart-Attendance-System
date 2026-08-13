# 📱 Attendify – Smart Location-Bound QR Attendance System

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web%20%7C%20iOS-brightgreen?style=for-the-badge)]()
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

**Attendify** is an enterprise-ready, cross-platform smart attendance management system built with **Flutter** and **Firebase**. It eliminates proxy attendance and buddy-punching using **time-bound dynamic QR codes**, **real-time GPS geofencing**, **device locking (single-device verification)**, and **multi-tenant role-based access control (RBAC)**.

---

## 🌟 Key Features

### 📍 1. Location-Bound Dynamic QR Attendance
- **Dynamic Rolling QR**: QR codes regenerate automatically every 5 seconds with cryptographically signed time-stamps to prevent photo sharing or screenshot distribution.
- **Strict Geofencing**: Teachers define a physical radius (e.g., 50m). Students can only mark attendance if their verified GPS coordinates fall inside the designated zone.
- **Live Proxy Detection**: Unauthorized attempts outside the geofence or with expired QR tokens are blocked instantly and flagged to the instructor.

### 🔒 2. Hardware Device Locking & Security
- **Single-Device Binding**: A student account binds to their unique physical device identifier (`device_info_plus` / secure storage).
- **Anti-Proxy Protection**: Multiple logins across different devices are prevented in real time.

### 🏢 3. Multi-Tenant Architecture & Roles
- **👑 Super Admin**: Platform-wide oversight, institution provisioning, global metrics, and system audits.
- **🏫 Institution Admin**: Institution department management, user approvals, course scheduling, and analytical reports.
- **👨‍🏫 Teacher / Instructor**: Dynamic QR session generation, geofence radius adjustment, live attendee stream, manual override, and CSV/PDF export.
- **🎓 Student**: Instant camera QR scanning with live GPS proximity indicator, personal attendance history, and subject breakdown.

---

## 🏗️ Architecture & Project Structure

```
Attendify/
├── android/                   # Android native platform configuration & permissions
├── ios/                       # iOS native platform configuration
├── web/                       # Web entrypoint, manifest & service worker
├── lib/
│   ├── main.dart              # App initialization & Firebase bootstrap
│   ├── app.dart               # MaterialApp, router config & theme provider
│   ├── firebase_options.dart  # Firebase platform configuration
│   ├── core/                  # Core utilities, theme tokens, router & constants
│   │   ├── router.dart        # Declarative routing with go_router & role guards
│   │   └── theme.dart         # Attendify design system & color palettes
│   └── features/              # Feature-driven modular architecture
│       ├── auth/              # Authentication & role management
│       ├── super_admin/       # Super admin dashboards & institution provisioning
│       ├── admin/             # Institution admin controls & batch analytics
│       ├── teacher/           # Dynamic QR session generator & live attendees
│       ├── student/           # QR scanner & personal attendance tracker
│       ├── attendance/        # Attendance models, services & validations
│       ├── institutions/      # Multi-tenant organization handling
│       └── shared/            # Reusable UI widgets, stat cards & chart components
├── firestore.rules            # Firestore security rules enforcing RBAC & multi-tenancy
├── firestore.indexes.json     # Firestore composite query indexes
├── firebase.json              # Firebase project configuration & hosting setup
└── pubspec.yaml               # Dependencies & asset declarations
```

---

## 🚀 Getting Started: How to Run Locally

Follow these instructions to set up, configure, and run **Attendify** on your local machine.

### 📋 Prerequisites

Make sure you have the following installed on your development machine:
1. **Flutter SDK** (version 3.3.0 or newer): [Install Flutter](https://docs.flutter.dev/get-started/install)
2. **Dart SDK** (included with Flutter)
3. **Android Studio** / **VS Code** with Flutter & Dart extensions
4. **Google Chrome** (for testing web platform)
5. **Firebase CLI** (optional, for deploying rules & cloud functions): `npm install -g firebase-tools`

Verify your setup by running:
```bash
flutter doctor
```

---

### 📥 Step 1: Clone the Repository

```bash
git clone https://github.com/Bibek-Kumar-Thagunna/Attendify-Smart-Attendance-System.git
cd Attendify-Smart-Attendance-System
```

---

### 📦 Step 2: Install Dependencies

Fetch all required Dart and Flutter packages:
```bash
flutter pub get
```

---

### ⚙️ Step 3: Firebase Configuration

Attendify uses Firebase for authentication and database services.

1. Create a Firebase project at the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Firebase Authentication** (Email/Password or Anonymous for demo).
3. Enable **Cloud Firestore Database**.
4. Configure FlutterFire using the FlutterFire CLI:
   ```bash
   flutterfire configure
   ```
5. *(Optional)* Deploy Firestore security rules and composite indexes:
   ```bash
   firebase login
   firebase deploy --only firestore
   ```

---

### 💻 Step 4: Run the Application Locally

#### 🌐 Running on Web (Chrome):
```bash
flutter run -d chrome
```
*Tip: To test with CanvasKit rendering engine:*
```bash
flutter run -d chrome --web-renderer canvaskit
```

#### 📱 Running on Android (Emulator or Connected Device):
1. Connect your Android device via USB (with USB Debugging enabled) or start an Android Emulator from Android Studio.
2. Check connected devices:
   ```bash
   flutter devices
   ```
3. Run the app:
   ```bash
   flutter run -d <device_id>
   # Or simply:
   flutter run
   ```

---

### 📦 Step 5: Building for Production

#### Build Web Application:
```bash
flutter build web --release
```
The compiled static website will be generated in `build/web/`.

#### Build Android APK:
```bash
flutter build apk --release
```
The installable APK will be output at `build/app/outputs/flutter-apk/app-release.apk`.

#### Build Android App Bundle (for Google Play):
```bash
flutter build appbundle --release
```

---

## 🔑 Required Permissions

| Permission | Platform | Purpose |
|---|---|---|
| `CAMERA` | Android / iOS / Web | Capturing and scanning dynamic QR codes in real time |
| `ACCESS_FINE_LOCATION` | Android / iOS / Web | Accurate GPS coordinates for geofence distance verification |
| `ACCESS_COARSE_LOCATION` | Android / iOS / Web | Approximate location fallback |
| `INTERNET` | Android / iOS / Web | Real-time synchronization with Firebase Cloud Firestore |

> **Note for Web:** Browsers require HTTPS (or `localhost`) to access camera and geolocation APIs due to browser security policies.

---

## 🛠️ Tech Stack & Key Libraries

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **State Management**: [Riverpod](https://riverpod.dev) (`flutter_riverpod`)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **Backend & Database**: [Firebase Auth](https://firebase.google.com/products/auth), [Cloud Firestore](https://firebase.google.com/products/firestore), [Firebase Hosting](https://firebase.google.com/products/hosting)
- **QR Code Scanning & Generation**: [`mobile_scanner`](https://pub.dev/packages/mobile_scanner), [`qr_flutter`](https://pub.dev/packages/qr_flutter)
- **Geolocation & Distance**: [`geolocator`](https://pub.dev/packages/geolocator)
- **Data Visualization**: [`fl_chart`](https://pub.dev/packages/fl_chart)
- **Device Security**: [`device_info_plus`](https://pub.dev/packages/device_info_plus), [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!
Feel free to check the [issues page](https://github.com/Bibek-Kumar-Thagunna/Attendify-Smart-Attendance-System/issues).
