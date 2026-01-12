import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'ui/screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 設定狀態列樣式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  // 鎖定螢幕方向為直式
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const FogApp());
}

/// Fog App
///
/// 現實世界 Fog MVP 主應用程式。
class FogApp extends StatelessWidget {
  const FogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Fog',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F0F14),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF4A90D9),
            secondary: Color(0xFFE57373),
            surface: Color(0xFF1A1A1F),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Colors.white,
          ),
          fontFamily: 'SF Pro Text',
        ),
        home: const MapScreen(),
      ),
    );
  }
}
