# 🚀 Handoff Guide: Zone 14 Membership Scanner

This project is a high-performance membership scanner for stadium entry management, built with Flutter and Firebase.

## 📋 Project Status
- **Core Features**: Functional OCR scanner, multi-zone filtering, real-time attendance tracking, permanent scan history, and attendance reset.
- **Platforms**: Android (APK), iOS (Native/Web PWA), Web.
- **CI/CD**: Fully automated via GitHub Actions (Android, iOS, Web PWA).

## 🛠 Tech Stack
- **Framework**: Flutter (Dart)
- **Database**: Firebase Firestore (`members` and `scans_history` collections).
- **OCR**: Google ML Kit Text Recognition (On-device).
- **CI/CD**: GitHub Actions (MacOS runners for iOS, Ubuntu for Android/Web).

## 📂 Key Files to Hand Over
- `lib/`: All application logic.
    - `main.dart`: Entry point & navigation.
    - `scanner_screen.dart`: OCR logic & feedback.
    - `members_list_screen.dart`: attendance view & reset.
    - `history_screen.dart`: Permanent logs.
    - `data_manager.dart`: Member seeding & database cleanup.
- `.github/workflows/`: Critical CI/CD scripts.
    - `ios.yml`: Optimized with Ruby to handle deployment targets (iOS 13.0).
    - `android.yml`: Standard APK generation.
    - `web_pwa.yml`: Deployment to GitHub Pages.
- `pubspec.yaml`: Dependencies (Note: `intl: ^0.20.2` is required for compatibility).
- `google-services.json` (Android) & `GoogleService-Info.plist` (iOS): Firebase config files.

## 🚀 How to Continue the Work
1. **GitHub Collaboration**: The user has sent you an invitation to the repository. Accept it to pull/push.
2. **Adding Members**: Update `DataManager.seedInitialMembers()` or import directly to Firestore.
3. **Triggering Builds**: Simply push to `master` or `main`.
4. **iOS Build Note**: The `ios.yml` workflow automatically regenerates the iOS folder and fixes permissions/deployment targets using Ruby. Do not manually edit the `ios/` folder unless necessary; use the workflow for consistency.

## 📌 Next Steps
- Integrate the full member lists for the 14 zones.
- Test the OCR accuracy under stadium lighting conditions.
- Finalize App Store/Play Store distribution if required.

---
**Maintained by Antigravity AI Agent**
*Good luck with the project!*
