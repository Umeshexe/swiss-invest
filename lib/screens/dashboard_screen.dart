import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/app_controller.dart';
import '../models/permission_snapshot.dart';
import '../widgets/settings_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? _pendingRecords;
  bool _isLoadingPending = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPendingEstimate();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingEstimate({bool forceRefresh = false}) async {
    if (_isLoadingPending) {
      return;
    }

    _isLoadingPending = true;
    try {
      final count = await widget.controller.estimateRecordsReady(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _pendingRecords = count;
        });
      }
      await widget.controller.refreshDeviceHealthSnapshot();
    } finally {
      _isLoadingPending = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFFE2F0E8),
            foregroundColor: const Color(0xFF0B5D52),
            title: const Text(
              'Health Sync Dashboard',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                tooltip: 'Settings',
                onPressed: () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => SettingsSheet(controller: controller),
                  );
                  if (mounted) {
                    await _loadPendingEstimate(forceRefresh: true);
                  }
                },
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => _loadPendingEstimate(forceRefresh: true),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + bottomInset),
                children: [
                  _SummaryCard(controller: controller),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Last Sync',
                          value: _formatLastSync(controller.lastSyncAt),
                          icon: Icons.schedule,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: 'Pending Records',
                          value: _isLoadingPending
                              ? 'Checking...'
                              : (_pendingRecords?.toString() ?? '--'),
                          icon: Icons.data_usage,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Health',
                          value: _formatPermission(
                            controller.permissionSnapshot.health,
                          ),
                          icon: Icons.favorite,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          title: 'Location',
                          value: _formatPermission(
                            controller.permissionSnapshot.location,
                          ),
                          icon: Icons.location_on,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Device Health Snapshot',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _HealthSnapshotPanel(controller: controller),
                  const SizedBox(height: 24),
                  Text(
                    'Manual Sync',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: controller.isSyncing
                        ? null
                        : () async {
                            await controller.syncNow();
                            if (mounted) {
                              await _loadPendingEstimate(forceRefresh: true);
                            }
                          },
                    icon: controller.isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      controller.isSyncing ? 'Syncing...' : 'Sync Now',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isLoadingPending
                        ? null
                        : () => _loadPendingEstimate(forceRefresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Device Snapshot'),
                  ),
                  const SizedBox(height: 24),
                  _InfoPanel(
                    title: 'Automatic Sync',
                    lines: const <String>[
                      'A background task is scheduled approximately every 24 hours.',
                      'Actual timing depends on Android and iOS battery policies.',
                      'If the OS delays it, sync resumes when the app opens again.',
                    ],
                  ),
                  const SizedBox(height: 20),
                  _InfoPanel(
                    title: 'Privacy Rules',
                    lines: const <String>[
                      'No permission means no data for that category.',
                      'Only new records after the last successful sync are uploaded.',
                      'Camera and microphone are permission-enabled only, not auto-synced.',
                      'All requests use HTTPS with bearer-token authentication.',
                    ],
                  ),
                  if (controller.lastSyncMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD8E0D6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Latest Status',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(controller.lastSyncMessage!),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatLastSync(DateTime? lastSyncAt) {
    if (lastSyncAt == null) {
      return 'Never';
    }

    return DateFormat('dd MMM, hh:mm a').format(lastSyncAt.toLocal());
  }

  String _formatPermission(PermissionState state) {
    switch (state) {
      case PermissionState.granted:
        return 'Granted';
      case PermissionState.permanentlyDenied:
        return 'Blocked';
      case PermissionState.unavailable:
        return 'Unavailable';
      case PermissionState.denied:
        return 'Denied';
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B5D52), Color(0xFF4C9F70)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Secure device-to-cloud connector',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Text(
            controller.session?.email ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'User ID ${controller.session?.userId ?? '--'}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _HealthSnapshotPanel extends StatelessWidget {
  const _HealthSnapshotPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.deviceHealthSnapshot;

    if (!snapshot.hasAnyData) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD8E0D6)),
        ),
        child: Text(
          Platform.isAndroid
              ? 'No health values are visible yet from Health Connect. On some Android devices, Health Connect can be installed and permission can be granted, but there is still no data until a source app or wearable syncs steps/calories into Health Connect. If this phone already has health data, make sure it is actually writing into Health Connect, then refresh.'
              : 'No health values are visible yet from Apple Health. If the device has data, check that it is available in Apple Health and that access has been granted, then refresh.',
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Steps Today',
                value: snapshot.steps?.toString() ?? '--',
                icon: Icons.directions_walk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Calories',
                value: snapshot.calories == null
                    ? '--'
                    : '${snapshot.calories!.round()} kcal',
                icon: Icons.local_fire_department,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Sleep',
                value: _formatSleep(snapshot.sleepDuration),
                icon: Icons.bedtime,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Heart Rate',
                value: snapshot.heartRate == null
                    ? '--'
                    : '${snapshot.heartRate!.round()} bpm',
                icon: Icons.favorite_border,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Weight',
                value: snapshot.weight == null
                    ? '--'
                    : '${snapshot.weight!.toStringAsFixed(1)} kg',
                icon: Icons.monitor_weight_outlined,
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  String _formatSleep(Duration? duration) {
    if (duration == null) {
      return '--';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E0D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E0D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
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
