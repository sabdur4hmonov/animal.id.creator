import 'package:flutter/material.dart';
import 'capture_screen.dart';
import 'app_design.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BioLivestockApp());
}

class BioLivestockApp extends StatelessWidget {
  const BioLivestockApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'BioLivestock Capture',
    debugShowCheckedModeBanner: false,
    theme: fieldTheme(),
    home: const CaptureScreen(),
  );
}
