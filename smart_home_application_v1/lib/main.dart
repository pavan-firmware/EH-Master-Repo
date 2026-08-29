import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/device_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceStorageService.init();
  runApp(const SmartHomeApp());
}
