import 'package:flutter/material.dart';
import '../models/app_context.dart';
import 'context_select_screen.dart';
import 'robot_screen.dart';

class RobotMapRouterScreen extends StatelessWidget {
  const RobotMapRouterScreen({super.key, required this.ctx});
  final AppContext ctx;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
        title: Text(ctx.breadcrumb),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ContextSelectScreen())),
            child: const Text('Change')),
          const SizedBox(width: 8),
        ],
      ),
      body: _resolveMap(ctx),
    );
  }

  Widget _resolveMap(AppContext ctx) {
    if (ctx.region == 'KR' && ctx.site == 'Office' && ctx.floor == '2F') {
      return const RobotScreen();
    }
    return Center(
      child: Text('No map configured for\n${ctx.breadcrumb}',
        textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)));
  }
}
