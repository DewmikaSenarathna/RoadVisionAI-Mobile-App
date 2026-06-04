import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const RoadVisionMobileApp());
}

class RoadVisionMobileApp extends StatelessWidget {
  const RoadVisionMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RoadVisionAI',
      theme: buildRoadVisionTheme(),
      home: const SplashScreen(),
    );
  }
}