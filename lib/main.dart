import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/setup_service.dart';
import 'services/tag_group_service.dart';
import 'services/map_zone_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    SetupService.instance.load(),
    TagGroupService.instance.load(),
    MapZoneService.instance.load(),
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HAMMER',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const LoginScreen(),
    );
  }
}
