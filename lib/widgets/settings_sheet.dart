import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/app_controller.dart';
import '../models/permission_snapshot.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.controller});

  final AppController controller;

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
                  onPressed: controller.requestHealthPermission,
                ),
                _PermissionTile(
                  title: 'Location',
                  icon: Icons.location_on,
                  state: snapshot.location,
                  onPressed: controller.requestLocationPermission,
                ),
                _PermissionTile(
                  title: 'Camera',
                  icon: Icons.photo_camera,
                  state: snapshot.camera,
                  onPressed: controller.requestCameraPermission,
                ),
                _PermissionTile(
                  title: 'Microphone',
                  icon: Icons.mic,
                  state: snapshot.microphone,
                  onPressed: controller.requestMicrophonePermission,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings_applications),
                  label: const Text('Open System Settings'),
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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(granted ? 'Granted' : state.name),
      trailing: TextButton(onPressed: onPressed, child: const Text('Request')),
    );
  }
}
