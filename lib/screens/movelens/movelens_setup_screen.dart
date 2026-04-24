import 'package:flutter/material.dart';

import '../../models/movelens_center.dart';
import 'tabs/center_tab.dart';
import 'tabs/map_annotation_tab.dart';
import 'tabs/tag_mapping_tab.dart';
import 'tabs/measurement_tab.dart';
import 'movelens_session_screen.dart';

class MoveLensSetupScreen extends StatefulWidget {
  final bool isNew;
  final MoveLensCenter? center;
  final int initialTab;

  const MoveLensSetupScreen({
    super.key,
    required this.isNew,
    this.center,
    this.initialTab = 0,
  });

  @override
  State<MoveLensSetupScreen> createState() => _MoveLensSetupScreenState();
}

class _MoveLensSetupScreenState extends State<MoveLensSetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  MoveLensCenter? _center;

  static const _tabs = ['센터 등록', '맵 & Zone', '태그 매핑', '측정 설정'];

  @override
  void initState() {
    super.initState();
    _center = widget.center;
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, _tabs.length - 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onCenterSaved(MoveLensCenter c) {
    setState(() => _center = c);
    // 저장 후 다음 탭으로 이동
    if (_tabController.index == 0) {
      _tabController.animateTo(1);
    }
  }

  void _startMeasurement() {
    if (_center == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MoveLensSessionScreen(center: _center!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '신규 센터 등록' : (_center?.name ?? '센터 설정')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: 센터 등록
          MoveLensCenterTab(
            center: _center,
            onSaved: _onCenterSaved,
          ),
          // Tab 1: 맵 & Zone
          _center == null
              ? _noCenter()
              : MoveLensMapAnnotationTab(center: _center!),
          // Tab 2: 태그 매핑
          _center == null
              ? _noCenter()
              : MoveLensTagMappingTab(center: _center!),
          // Tab 3: 측정 설정
          _center == null
              ? _noCenter()
              : MoveLensMeasurementTab(
                  center: _center!,
                  onStartMeasurement: _startMeasurement,
                ),
        ],
      ),
    );
  }

  Widget _noCenter() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: Colors.grey[400], size: 48),
            const SizedBox(height: 12),
            Text(
              '센터 등록 탭에서 먼저 센터를 저장해주세요',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('센터 등록으로 이동'),
            ),
          ],
        ),
      );
}
