import 'package:flutter/material.dart';
import 'center_location_tab.dart';
import 'anchor_tab.dart';
import 'tag_tab.dart';
import 'robot_mapping_tab.dart';
import 'connection_test_tab.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: const Text('Setup'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.business), text: '센터 / 로케이션'),
              Tab(icon: Icon(Icons.router), text: 'Anchor'),
              Tab(icon: Icon(Icons.nfc), text: 'Tag'),
              Tab(icon: Icon(Icons.precision_manufacturing), text: '로봇 매핑'),
              Tab(icon: Icon(Icons.wifi_tethering), text: 'Connection Test'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CenterLocationTab(),
            AnchorTab(),
            TagTab(),
            RobotMappingTab(),
            ConnectionTestTab(),
          ],
        ),
      ),
    );
  }
}
