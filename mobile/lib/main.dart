import 'package:flutter/material.dart';
import 'capture_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BioLivestockApp());
}

class BioLivestockApp extends StatelessWidget {
  const BioLivestockApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BioLivestock Capture',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff24634b)),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    ),
    home: const CaptureScreen(),
  );
}

