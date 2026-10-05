import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/app_controller.dart';
import 'core/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ShoulderOsApp(controller: AppController(AppDatabase())));
}
