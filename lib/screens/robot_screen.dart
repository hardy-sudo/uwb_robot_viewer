import 'package:flutter/material.dart';
import '../models/robot_data.dart';
import '../widgets/robot_dot.dart';
import '../widgets/grid_overlay.dart';

class RobotScreen extends StatefulWidget {
  const RobotScreen({super.key});
  @override
  State<RobotScreen> createState() => _RobotScreenState();
}

class _RobotScreenState extends State<RobotScreen> {
  final double maxX = 6.0;
  final double maxY = 6.0;
  late final List<RobotData> robots;
  late final Map<String, TextEditingController> xCtrl, yCtrl;

  @override
  void initState() {
    super.initState();
    robots = [
      RobotData(id: 'R1', color: Colors.blue,   currentX: 1.0, currentY: 1.0),
      RobotData(id: 'R2', color: Colors.green,  currentX: 3.0, currentY: 2.0),
      RobotData(id: 'R3', color: Colors.orange, currentX: 5.0, currentY: 5.0),
    ];
    xCtrl = { for (final r in robots) r.id: TextEditingController(text: r.currentX.toStringAsFixed(2)) };
    yCtrl = { for (final r in robots) r.id: TextEditingController(text: r.currentY.toStringAsFixed(2)) };
  }

  @override
  void dispose() {
    for (final c in xCtrl.values) c.dispose();
    for (final c in yCtrl.values) c.dispose();
    super.dispose();
  }

  void _apply() {
    setState(() {
      for (final r in robots) {
        final x = double.tryParse(xCtrl[r.id]!.text);
        final y = double.tryParse(yCtrl[r.id]!.text);
        if (x != null) r.currentX = x.clamp(0.0, maxX);
        if (y != null) r.currentY = y.clamp(0.0, maxY);
        xCtrl[r.id]!.text = r.currentX.toStringAsFixed(2);
        yCtrl[r.id]!.text = r.currentY.toStringAsFixed(2);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(aspectRatio: 1, child: LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth, h = constraints.maxHeight;
            return Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: Stack(children: [
                Positioned.fill(child: GridOverlay(maxX: maxX, maxY: maxY)),
                for (final r in robots) _marker(r, w, h),
              ]));
          })),
          const SizedBox(height: 20),
          const Text('좌표 입력 (m) — 0~6 범위', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (final r in robots) Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(width: 40, child: Text(r.id, style: const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(child: TextField(controller: xCtrl[r.id], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'X', isDense: true, border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: yCtrl[r.id], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Y', isDense: true, border: OutlineInputBorder()))),
            ])),
          Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: _apply, child: const Text('Apply'))),
          const SizedBox(height: 16),
          const Text('현재 로봇 위치', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...robots.map((r) => Text('${r.id}: X=${r.currentX.toStringAsFixed(2)} m, Y=${r.currentY.toStringAsFixed(2)} m')),
          const SizedBox(height: 10),
          const Text('※ 나중에 WebSocket 실시간 연동으로 교체 예정', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _marker(RobotData r, double w, double h) {
    return Positioned(
      left: (r.currentX / maxX) * w - 12,
      top: (1 - r.currentY / maxY) * h - 12,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        RobotDot(color: r.color),
        const SizedBox(height: 2),
        Text(r.id, style: const TextStyle(fontSize: 10)),
      ]));
  }
}
