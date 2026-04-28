import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/app_controller.dart';
import '../models/permission_snapshot.dart';
import 'about_app_sheet.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.controller});

  final AppController controller;

  Future<void> _handlePermissionRequest(
    BuildContext context,
    String title,
    Future<PermissionState> Function() request,
  ) async {
    final state = await request();
    if (!context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    switch (state) {
      case PermissionState.granted:
        messenger.showSnackBar(
          SnackBar(content: Text('$title permission granted.')),
        );
      case PermissionState.permanentlyDenied:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '$title permission is blocked. Open system settings to enable it.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: openAppSettings,
            ),
          ),
        );
      case PermissionState.denied:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '$title permission was not granted. You can try again or enable it in Settings.',
            ),
          ),
        );
      case PermissionState.unavailable:
        messenger.showSnackBar(
          SnackBar(
            content: Text('$title permission is unavailable on this device.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final snapshot = controller.permissionSnapshot;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage permission access and account controls for sync.',
                ),
                const SizedBox(height: 16),
                _PermissionTile(
                  title: 'Health Data',
                  icon: Icons.favorite,
                  state: snapshot.health,
                  onPressed: () => _handlePermissionRequest(
                    context,
                    'Health Data',
                    controller.requestHealthPermission,
                  ),
                ),
                _PermissionTile(
                  title: 'Location',
                  icon: Icons.location_on,
                  state: snapshot.location,
                  onPressed: () => _handlePermissionRequest(
                    context,
                    'Location',
                    controller.requestLocationPermission,
                  ),
                ),
                _PermissionTile(
                  title: 'Camera',
                  icon: Icons.photo_camera,
                  state: snapshot.camera,
                  onPressed: () => _handlePermissionRequest(
                    context,
                    'Camera',
                    controller.requestCameraPermission,
                  ),
                ),
                _PermissionTile(
                  title: 'Microphone',
                  icon: Icons.mic,
                  state: snapshot.microphone,
                  onPressed: () => _handlePermissionRequest(
                    context,
                    'Microphone',
                    controller.requestMicrophonePermission,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings_applications),
                  label: const Text('Open System Settings'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => const FractionallySizedBox(
                        heightFactor: 0.92,
                        child: AboutAppSheet(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('About App'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    controller.logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.icon,
    required this.state,
    required this.onPressed,
  });

  final String title;
  final IconData icon;
  final PermissionState state;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final granted = state == PermissionState.granted;
    final blocked = state == PermissionState.permanentlyDenied;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(granted ? 'Granted' : state.name),
      trailing: TextButton(
        onPressed: granted ? openAppSettings : onPressed,
        child: Text(
          granted
              ? 'Manage'
              : blocked
              ? 'Settings'
              : 'Request',
        ),
      ),
    );
  }
}
