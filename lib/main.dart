import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'services/background_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundSyncService.initialize();
  runApp(const OrionApp());
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await BackgroundSyncService.performBackgroundSync(task);
    return Future<bool>.value(true);
  });
}
