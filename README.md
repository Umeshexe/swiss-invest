# Orion Health Data Sync App

Flutter assignment project for a health-data sync mobile app.

The app acts as a secure bridge between native device data sources and the provided backend API. It authenticates the user, requests permissions one by one, reads only approved health/location data, and syncs that data securely to the backend.

## Features

- User login with `POST /api/auth/login`
- Secure bearer-token storage
- Step-by-step permission onboarding
- Health data integration
  - Android: Health Connect
  - iOS: Apple Health / HealthKit
- Location permission and location payload support
- Manual sync with `Sync Now`
- Background sync scheduling hook for roughly every 24 hours
- Incremental sync using last successful sync timestamp
- Settings screen with permission re-request and logout

## API Endpoints

Base URL:

```text
https://orishub.com
```

Endpoints used:

- `POST /api/auth/login`
- `POST /api/submissions`
- `GET /api/submissions/{user_id}`

Example submission body:

```json
{
  "type": "Health Connector Data",
  "device_id": "android-3996",
  "user_id": 3996,
  "payload": {
    "steps": [],
    "heart_rate": [],
    "calories": [],
    "sleep": [],
    "weight": [],
    "location": []
  }
}
```

## Permission Rules

The app follows the assignment privacy rules:

- permissions are requested individually
- no permission means no data collection for that category
- camera and microphone are permission-enabled only, not part of auto sync
- no hidden background recording
- sync sends only new records after the last successful sync

## Sync Strategy

Two sync modes are implemented:

- Manual sync
  - triggered by the `Sync Now` button
  - reads latest approved device data and uploads immediately

- Automatic sync
  - scheduled through background work
  - intended to run roughly every 24 hours
  - actual execution timing depends on Android/iOS system policies

Incremental sync:

- the app stores the last successful sync timestamp
- future syncs only read records after that timestamp
- this avoids repeatedly resending full history

## Project Structure

```text
lib/
  app.dart
  main.dart
  controllers/
  models/
  screens/
  services/
  widgets/
```

Key files:

- [lib/app.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/app.dart)
- [lib/controllers/app_controller.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/controllers/app_controller.dart)
- [lib/services/api_service.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/services/api_service.dart)
- [lib/services/sync_service.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/services/sync_service.dart)
- [lib/services/device_data_service.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/services/device_data_service.dart)

## Run Locally

Requirements:

- Flutter SDK
- Android Studio / Xcode
- Android device with Health Connect available for Android testing

Commands:

```bash
flutter pub get
flutter run
```

Useful checks:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Platform Notes

### Android

- uses Health Connect for health data
- requires activity recognition, health, location, camera, and microphone permissions
- background work is scheduled through `workmanager`

### iOS

- uses HealthKit / Apple Health
- includes HealthKit entitlement and permission descriptions
- background execution timing is OS-controlled and not guaranteed to run at exact 24-hour intervals

## Assignment Scope Notes

This project is built as an MVP for the assignment, with the focus on:

- permissions
- health data sync
- backend integration
- incremental sync
- privacy-safe behavior

It is not intended as a production-complete medical app.

## Validation

Project validation completed locally:

- `flutter analyze` passed
- `flutter test` passed
- Android debug APK build completed successfully

## Final Note

Before final submission, do one real device end-to-end check:

1. log in with a valid account
2. grant permissions
3. press `Sync Now`
4. confirm the backend accepts the submission
5. confirm sync status updates on the dashboard
