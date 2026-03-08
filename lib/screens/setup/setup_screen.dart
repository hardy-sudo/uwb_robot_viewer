import 'package:flutter/material.dart';
import 'center_location_tab.dart';
import 'anchor_tab.dart';
import 'tag_tab.dart';
import 'robot_mapping_tab.dart';
import 'connection_test_tab.dart';
import 'safety_settings_tab.dart';
import 'relation_tab.dart';
import 'map_zone_tab.dart';

class SetupScreen extends StatefulWidget {
  final int initialTab;

  const SetupScreen({super.key, this.initialTab = 0});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    Tab(icon: Icon(Icons.business), text: '센터 / 로케이션'),
    Tab(icon: Icon(Icons.router), text: 'Anchor'),
    Tab(icon: Icon(Icons.nfc), text: 'Tag'),
    Tab(icon: Icon(Icons.precision_manufacturing), text: '로봇 매핑'),
    Tab(icon: Icon(Icons.wifi_tethering), text: 'Connection Test'),
    Tab(icon: Icon(Icons.shield), text: 'Safety'),
    Tab(icon: Icon(Icons.share), text: 'Relation'),
    Tab(icon: Icon(Icons.map), text: 'Map & Zone'),
  ];

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Setup'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CenterLocationTab(),
          AnchorTab(),
          TagTab(),
          RobotMappingTab(),
          ConnectionTestTab(),
          SafetySettingsTab(),
          RelationTab(),
          MapZoneTab(),
        ],
      ),
    );
  }
}
