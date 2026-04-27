import 'package:flutter/material.dart';

class AboutAppSheet extends StatefulWidget {
  const AboutAppSheet({super.key});

  @override
  State<AboutAppSheet> createState() => _AboutAppSheetState();
}

class _AboutAppSheetState extends State<AboutAppSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About App', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Project summary, architecture, testing notes, and edge cases for this assignment submission.',
            ),
            const SizedBox(height: 16),
            Flexible(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _AboutSection(
                        title: 'What This App Does',
                        lines: [
                          'Logs the user in with the provided backend API.',
                          'Requests permissions individually for health, location, camera, and microphone.',
                          'Reads approved health and location data only after permission is granted.',
                          'Syncs data manually and through scheduled background work.',
                        ],
                      ),
                      _AboutSection(
                        title: 'Login and API',
                        lines: [
                          'Uses POST https://orishub.com/api/auth/login with raw JSON email/password.',
                          'Stores the returned access token securely.',
                          'Uses bearer token authorization for future sync requests.',
                          'Submits health payloads to POST /api/submissions.',
                        ],
                      ),
                      _AboutSection(
                        title: 'Architecture Used',
                        lines: [
                          'Controller + service based Flutter architecture.',
                          'Screens handle presentation.',
                          'AppController coordinates auth, permissions, and sync state.',
                          'Services handle API, storage, permissions, background tasks, and device data.',
                        ],
                      ),
                      _AboutSection(
                        title: 'System Design',
                        lines: [
                          'Login -> permission setup -> dashboard -> sync operations.',
                          'Health and location data are normalized into a backend payload.',
                          'Last successful sync time is stored locally.',
                          'Future syncs send only data newer than the last successful sync.',
                        ],
                      ),
                      _AboutSection(
                        title: 'Platforms',
                        lines: [
                          'Android uses Health Connect.',
                          'iOS uses Apple Health / HealthKit.',
                          'iOS permission descriptions and HealthKit entitlement are configured in the project.',
                        ],
                      ),
                      _AboutSection(
                        title: 'Testing Done',
                        lines: [
                          'flutter analyze passed.',
                          'flutter test passed.',
                          'Android debug APK build passed.',
                          'Health Connect permission flow and dashboard interactions were validated during development.',
                        ],
                      ),
                      _AboutSection(
                        title: 'Edge Cases Handled',
                        lines: [
                          'Permission denied for any category.',
                          'No new records available for sync.',
                          'No active session available.',
                          'Repeated dashboard refreshes while estimate is already running.',
                          'Safe-area and overflow issues on smaller screens.',
                        ],
                      ),
                      _AboutSection(
                        title: 'Background Sync Note',
                        lines: [
                          'Background sync is scheduled for roughly every 24 hours using OS-approved background execution.',
                          'Exact timing is controlled by Android and iOS system policies.',
                          'Manual sync remains available for immediate updates.',
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final line in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 7, color: Color(0xFF0B5D52)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(line)),
              ],
            ),
            if (line != lines.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
