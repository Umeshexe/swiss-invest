# Orion Health Data Sync App

Flutter assignment submission for a health data sync mobile app.

The app acts as a secure bridge between the phone and the provided backend. It authenticates the user, asks permissions category by category, reads only approved device data, and syncs that data securely using bearer-token authenticated API calls.

## Assignment Goal

Build a Flutter mobile app that:

- logs the user in with the provided backend API
- requests permissions individually
- reads approved health and location data from the device
- syncs data manually and automatically
- sends only new data, not the full history every time
- respects privacy and OS limitations

## Implemented Features

- Login with `POST /api/auth/login`
- Secure session storage
- Step-by-step permission setup
  - Health
  - Location
  - Camera
  - Microphone
- Health data integration
  - Android: Health Connect
  - iOS: Apple Health / HealthKit
- Location collection for sync payload
- Manual sync via `Sync Now`
- Background sync scheduling hook using `workmanager`
- Incremental sync based on last successful sync timestamp
- Dashboard with sync state and last sync info
- Settings with permission re-request, system settings shortcut, logout, and app details
- In-app `About App` section with architecture, testing, and edge-case notes

## API Details Used

Base URL:

```text
https://orishub.com
```

Endpoints:

- `POST /api/auth/login`
- `POST /api/submissions`
- `GET /api/submissions/{user_id}`

Headers used for login:

```text
Accept: application/json
Content-Type: application/json
```

Login request body:

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

Submission request format:

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

## Login Flow

1. User enters email and password.
2. App calls `POST /api/auth/login`.
3. Backend returns `access_token` and user information including `user_id`.
4. App stores the session securely.
5. All future sync requests use:

```text
Authorization: Bearer <token>
```

This matches the requirement shared in the WhatsApp messages:

- user logs in and gets token
- body is raw JSON
- bearer token is used for future requests

## Permissions Strategy

Permissions are requested one by one, not bundled.

Implemented rules:

- no permission means no collection for that category
- health data is read only after approval
- location is used only after approval
- camera and microphone are permission-enabled only and not part of background sync
- permissions can be revisited later in Settings

## Sync Modes

### Manual Sync

- User taps `Sync Now`
- App refreshes permission state
- App reads currently approved device data
- App sends the payload immediately

### Automatic Sync

- Implemented with background task scheduling
- Intended frequency is roughly every 24 hours
- Exact execution time is OS-controlled
- If the OS delays execution, the app can resume sync when opened again

## Incremental Sync Logic

The app does not resend full history on every sync.

Strategy:

- after a successful sync, store `lastSuccessfulSyncAt`
- next sync reads records only after that timestamp
- upload only the new set of records

Benefits:

- avoids duplicate full-history uploads
- reduces network usage
- matches the assignment requirement

## System Design

High-level flow:

1. User logs in
2. App stores token securely
3. User grants permissions one by one
4. App reads approved health/location data from native platform sources
5. App builds a normalized payload
6. App sends payload to backend with bearer token
7. App stores last successful sync timestamp
8. Future syncs only upload new data

## Architecture Used

This project uses a simple controller + service structure suitable for an MVP assignment.

### Layers

- `screens/`
  - UI screens
- `widgets/`
  - reusable UI pieces
- `controllers/`
  - app orchestration and state updates
- `services/`
  - API, storage, permissions, background sync, and device data logic
- `models/`
  - auth session, permissions, payloads, and sync results

### Main Components

- `AppController`
  - single source of truth for session, permission state, and sync state
- `ApiService`
  - backend communication
- `DeviceDataService`
  - reads health and location data
- `SyncService`
  - builds and uploads sync payloads
- `BackgroundSyncService`
  - registers periodic background work
- `StorageService`
  - secure session storage and lightweight sync metadata persistence

## Files to Review

- [lib/app.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/app.dart)
- [lib/controllers/app_controller.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/controllers/app_controller.dart)
- [lib/services/api_service.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/services/api_service.dart)
- [lib/services/device_data_service.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/services/device_data_service.dart)
- [lib/services/sync_service.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/services/sync_service.dart)
- [lib/services/background_sync_service.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/services/background_sync_service.dart)
- [lib/screens/login_screen.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/screens/login_screen.dart)
- [lib/screens/permissions_screen.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/screens/permissions_screen.dart)
- [lib/screens/dashboard_screen.dart](/Users/umesh/Desktop/SwissInvest/orion/lib/screens/dashboard_screen.dart)

## Platform Coverage

### Android

- Health Connect integration configured
- permissions declared in manifest
- `FlutterFragmentActivity` used for Health Connect permission flow
- background work scheduling configured

### iOS

- HealthKit permission descriptions added in `Info.plist`
- location, camera, and microphone descriptions added
- HealthKit entitlement added
- background task identifier added
- AppDelegate background registration added

## Testing and Validation

Completed locally:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

Behavior tested in development:

- login UI flow
- permission screens
- Health Connect permission request path
- dashboard navigation
- manual sync flow wiring
- safe-area and scroll behavior improvements

## Edge Cases Handled

- user denies one or more permissions
- no session available
- no new records found for sync
- permission state changes after initial setup
- dashboard refresh while estimate is already running
- scrollable content on smaller screens
- bottom navigation bar overlap issues

## Important Mobile Limitations

The assignment message says the app should always run in the background even when closed. On modern mobile OS versions, this cannot be guaranteed literally.

Correct implementation behavior:

- periodic background work is scheduled
- the OS decides exact execution timing
- manual sync always provides an immediate path
- iOS is especially restrictive about exact background timing

This is the correct professional interpretation of the assignment.

## Run the Project

Requirements:

- Flutter SDK
- Android Studio or Xcode
- Android device with Health Connect for Android validation

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

## Suggested Final Submission Check

Before sending the assignment:

1. log in with a valid backend account
2. grant health and location permissions
3. trigger `Sync Now`
4. verify backend accepts the submission
5. verify last sync status updates
6. verify settings and about app section open correctly

## Final Summary

This app satisfies the assignment at MVP level:

- authentication
- permission-aware collection
- health/location sync
- incremental sync logic
- manual and scheduled sync
- privacy-safe behavior

It is designed as an assignment-quality implementation, not a production-complete medical app.
