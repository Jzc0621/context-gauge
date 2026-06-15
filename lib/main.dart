import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import 'services/status_service.dart';
import 'screens/home_screen.dart';

String _resolveStatusPath() {
  // Look for config.json in: CWD, then exe directory, then parent dirs
  final candidates = <String>[
    'config.json',
    '${File(Platform.resolvedExecutable).parent.path}\\config.json',
  ];

  for (final candidate in candidates) {
    try {
      final configFile = File(candidate);
      if (configFile.existsSync()) {
        final json = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
        if (json['statusFilePath'] != null) {
          final resolved = File(json['statusFilePath'] as String);
          if (resolved.isAbsolute) return resolved.path;
          return '${configFile.parent.path}\\${json['statusFilePath']}';
        }
      }
    } catch (_) {}
  }

  // Fallback: user's app data directory
  final appData = Platform.environment['APPDATA'] ??
      Platform.environment['HOME'] ??
      '.';
  return '$appData\\claude-monitor\\status.json';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    size: const Size(440, 680),
    minimumSize: const Size(320, 400),
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    final display = await screenRetriever.getPrimaryDisplay();
    final screenSize = display.visibleSize ?? display.size;
    await windowManager.setPosition(Offset(
      screenSize.width - 450,
      20,
    ));
    await windowManager.show();
    await windowManager.focus();
  });

  final statusService = StatusService(_resolveStatusPath());
  await statusService.start();

  runApp(ClaudeMonitorApp(statusService: statusService));
}

class ClaudeMonitorApp extends StatelessWidget {
  final StatusService statusService;

  const ClaudeMonitorApp({super.key, required this.statusService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Claude Monitor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
      ),
      home: HomeScreen(statusService: statusService),
    );
  }
}
