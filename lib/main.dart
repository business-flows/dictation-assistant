import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait on mobile, allow all on desktop
  final platform = PlatformDispatcher.instance.platformBrightness;
  debugPrint('Starting Dictation Assistant on ${PlatformDispatcher.instance.defaultRouteName}');

  // Initialize dependency injection
  await configureDependencies();

  runApp(const DictationApp());
}