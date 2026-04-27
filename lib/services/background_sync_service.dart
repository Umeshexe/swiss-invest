import 'package:workmanager/workmanager.dart';

import '../main.dart';
import '../models/auth_session.dart';
import '../models/permission_snapshot.dart';
import 'api_service.dart';
import 'device_data_service.dart';
import 'storage_service.dart';
import 'sync_service.dart';

class BackgroundSyncService {
  static const String periodicSyncTask = 'orion.periodic-health-sync';

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  static Future<void> schedulePeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      periodicSyncTask,
      periodicSyncTask,
      frequency: const Duration(hours: 24),
      initialDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> cancelPeriodicSync() async {
    await Workmanager().cancelByUniqueName(periodicSyncTask);
  }

  static Future<void> performBackgroundSync(String task) async {
    if (task != periodicSyncTask) {
      return;
    }

    final storage = StorageService();
    final session = await storage.readSession();
    if (session == null) {
      return;
    }

    final permissions = await storage.readPermissionSnapshot();
    await _runSync(
      storageService: storage,
      session: session,
      permissions: permissions,
    );
  }

  static Future<void> _runSync({
    required StorageService storageService,
    required AuthSession session,
    required PermissionSnapshot permissions,
  }) async {
    final syncService = SyncService(
      storageService: storageService,
      apiService: ApiService(),
      deviceDataService: DeviceDataService(),
    );

    await syncService.sync(
      session: session,
      permissions: permissions,
      source: 'background',
    );
  }
}
