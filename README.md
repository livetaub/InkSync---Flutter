# InkSync - Flutter Cross-Platform App

A complete cross-platform note-taking app built with Flutter for Android, iOS, and Web.

## Features

### Notes
- ✅ Create text notes and checklists
- ✅ 10 color options for organizing notes
- ✅ Pin notes to top
- ✅ Password protection (lock notes)
- ✅ Auto-save with 2-second debounce
- ✅ Drag-and-drop reorder for checklist items

### AI Writing Tools (Gemini)
- ✅ Proofread - Fix spelling & grammar
- ✅ Rephrase - Improve clarity
- ✅ Professional - Formal business tone
- ✅ Friendly - Casual conversational
- ✅ Emojify - Add relevant emojis
- ✅ Elaborate - Expand with details
- ✅ Shorten - Make concise

### Collaboration
- ✅ Invite collaborators by email
- ✅ Accept/decline invitations
- ✅ Real-time sync across devices

### Calendar
- ✅ Month view calendar
- ✅ Create/edit/delete events
- ✅ All-day and timed events
- ✅ Event reminders
- ✅ Color-coded events

### Search
- ✅ Full-text search across notes
- ✅ Search in title, content, checklist items
- ✅ Recent searches history

### Settings
- ✅ View mode (list/grid)
- ✅ Sort options (modified, created, A-Z, color)
- ✅ Notifications toggle
- ✅ Manual sync
- ✅ Premium upgrade

### Trash
- ✅ Soft delete to trash
- ✅ 30-day auto-deletion countdown
- ✅ Restore notes
- ✅ Permanent delete
- ✅ Empty trash

## Project Structure

```
lib/
├── config/
│   ├── app_config.dart        # API keys and constants
│   └── theme.dart             # App theme, colors, typography
├── screens/
│   ├── auth/
│   │   └── login_screen.dart  # Login/signup screen
│   ├── home/
│   │   └── home_screen.dart   # Notes list with grid/list view
│   ├── note_edit/
│   │   └── note_edit_screen.dart  # Note editor with all features
│   ├── calendar/
│   │   └── calendar_screen.dart   # Calendar with events
│   ├── search/
│   │   └── search_screen.dart     # Full-text search
│   ├── settings/
│   │   └── settings_screen.dart   # App settings
│   └── trash/
│       └── trash_screen.dart      # Deleted notes
├── services/
│   ├── auth_service.dart      # Firebase Authentication
│   ├── notes_service.dart     # Notes CRUD + models
│   ├── calendar_service.dart  # Calendar events CRUD
│   ├── settings_service.dart  # User preferences
│   ├── gemini_service.dart    # AI writing tools
│   └── services.dart          # Barrel export
├── widgets/
│   └── note_card.dart         # Note card component
├── firebase_options.dart      # Firebase configuration
└── main.dart                  # App entry point with navigation
```

## Setup

### 1. Install Flutter dependencies

```bash
cd flutter_app
flutter pub get
```

### 2. Configure Firebase (Recommended)

For proper platform-specific Firebase configuration:

```bash
# Install FlutterFire CLI (one-time)
dart pub global activate flutterfire_cli

# Configure Firebase for your project
flutterfire configure --project=tintnotes
```

This generates proper `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).

### 3. Run the app

```bash
# Run on Chrome (web)
flutter run -d chrome

# Run on Android device/emulator
flutter run -d android

# Run on iOS simulator (macOS only)
flutter run -d ios

# List available devices
flutter devices
```

## Building for Production

```bash
# Web
flutter build web
# Output: build/web/

# Android APK
flutter build apk
# Output: build/app/outputs/flutter-apk/app-release.apk

# Android App Bundle (for Play Store)
flutter build appbundle
# Output: build/app/outputs/bundle/release/app-release.aab

# iOS (macOS only)
flutter build ios
# Then open in Xcode: build/ios/Runner.xcworkspace
```

## Dependencies

| Package | Purpose |
|---------|---------|
| firebase_core | Firebase initialization |
| firebase_auth | User authentication |
| cloud_firestore | Real-time database |
| provider | State management |
| http | API calls (Gemini) |
| google_fonts | Typography (Inter) |
| flutter_slidable | Swipe actions |
| intl | Date formatting |
| go_router | Navigation (planned) |
| shared_preferences | Local storage |
| fluttertoast | Toast notifications |

## Shared Backend

This Flutter app uses the **same Firebase backend** as the React web app:
- Same Firestore database
- Same Authentication
- Data syncs in real-time between web and mobile

## Tech Stack

- **Framework:** Flutter 3.38+
- **Language:** Dart 3.10+
- **Platforms:** Android, iOS, Web
- **Backend:** Firebase (Firestore + Auth)
- **AI:** Google Gemini API
- **State:** Provider

## Known Issues

1. Dark mode - Not yet implemented (toggle visible but disabled)
2. Push notifications - Not yet implemented
3. Offline mode - Firestore handles basic offline caching

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open a Pull Request
