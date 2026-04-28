import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/app_controller.dart';
import '../models/permission_snapshot.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  int _currentStep = 0;
  final ScrollController _cardScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.refreshPermissionSnapshot();
  }

  @override
  void dispose() {
    _cardScrollController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission(
    String title,
    Future<PermissionState> Function() request,
  ) async {
    final state = await request();
    if (!mounted) {
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
    final controller = widget.controller;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final steps = <_PermissionStep>[
      _PermissionStep(
        title: 'Health Data',
        subtitle: 'Steps, heart rate, calories, sleep, weight',
        description:
            'Allow read-only access so the app can sync your available health records securely.',
        state: controller.permissionSnapshot.health,
        icon: Icons.favorite,
        accentColor: const Color(0xFFE15A64),
        onRequest: () => _requestPermission(
          'Health Data',
          controller.requestHealthPermission,
        ),
      ),
      _PermissionStep(
        title: 'Location',
        subtitle: 'GEO tagging and contextual data',
        description:
            'Allow location access to attach current location context during sync. No continuous tracking.',
        state: controller.permissionSnapshot.location,
        icon: Icons.location_on,
        accentColor: const Color(0xFF2B83C6),
        onRequest: () => _requestPermission(
          'Location',
          controller.requestLocationPermission,
        ),
      ),
      _PermissionStep(
        title: 'Camera',
        subtitle: 'User-triggered only',
        description:
            'Allow camera access for future user-triggered actions like scanning or uploads.',
        state: controller.permissionSnapshot.camera,
        icon: Icons.photo_camera,
        accentColor: const Color(0xFF8B61C9),
        onRequest: () =>
            _requestPermission('Camera', controller.requestCameraPermission),
      ),
      _PermissionStep(
        title: 'Microphone',
        subtitle: 'Voice features only',
        description:
            'Allow microphone access for optional voice features. Background recording is never used.',
        state: controller.permissionSnapshot.microphone,
        icon: Icons.mic,
        accentColor: const Color(0xFFD88748),
        onRequest: () => _requestPermission(
          'Microphone',
          controller.requestMicrophonePermission,
        ),
      ),
    ];

    final step = steps[_currentStep];

    return Scaffold(
      appBar: AppBar(title: const Text('Permission Setup')),
      body: SafeArea(
        bottom: true,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (_currentStep + 1) / steps.length,
                minHeight: 10,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 24),
              Text(
                'Choose what you want to allow',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'You can review and change these permissions later from Settings.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD8E0D6)),
                  ),
                  child: Scrollbar(
                    controller: _cardScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _cardScrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: step.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              step.icon,
                              color: step.accentColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            step.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            step.subtitle,
                            style: TextStyle(
                              color: step.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            step.description,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          _StatusChip(
                            state: step.state,
                            accentColor: step.accentColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: step.onRequest,
                icon: const Icon(Icons.verified_user),
                label: Text('Allow ${step.title}'),
                style: FilledButton.styleFrom(
                  backgroundColor: step.accentColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentStep == 0
                          ? null
                          : () {
                              setState(() {
                                _currentStep -= 1;
                              });
                            },
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () async {
                        if (_currentStep < steps.length - 1) {
                          setState(() {
                            _currentStep += 1;
                          });
                          return;
                        }
                        await controller.completePermissionSetup();
                      },
                      child: Text(
                        _currentStep == steps.length - 1 ? 'Continue' : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state, required this.accentColor});

  final PermissionState state;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final granted = state == PermissionState.granted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: granted ? accentColor.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: granted
              ? accentColor.withValues(alpha: 0.30)
              : const Color(0xFFD8E0D6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: granted ? accentColor : const Color(0xFF57645D),
          ),
          const SizedBox(width: 8),
          Text(
            granted ? 'Granted' : state.name,
            style: TextStyle(
              color: granted ? accentColor : const Color(0xFF57645D),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionStep {
  const _PermissionStep({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.state,
    required this.icon,
    required this.accentColor,
    required this.onRequest,
  });

  final String title;
  final String subtitle;
  final String description;
  final PermissionState state;
  final IconData icon;
  final Color accentColor;
  final Future<void> Function() onRequest;
}
