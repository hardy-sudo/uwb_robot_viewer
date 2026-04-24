import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/movelens_center.dart';
import '../../services/movelens_service.dart';
import 'movelens_setup_screen.dart';
import 'movelens_dashboard_screen.dart';
import 'movelens_session_screen.dart';

class MoveLensHomeScreen extends StatefulWidget {
  const MoveLensHomeScreen({super.key});

  @override
  State<MoveLensHomeScreen> createState() => _MoveLensHomeScreenState();
}

class _MoveLensHomeScreenState extends State<MoveLensHomeScreen> {
  final _svc = MoveLensService.instance;

  @override
  Widget build(BuildContext context) {
    final centers = _svc.centers;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: hammerYellow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Move',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const Text(
              'Lens',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w300,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '공정 진단',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '신규 센터 등록',
            onPressed: _addCenter,
          ),
        ],
      ),
      body: centers.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: centers.length,
              itemBuilder: (_, i) => _CenterCard(
                center: centers[i],
                onTap: () => _showCenterBottomSheet(centers[i]),
              ),
            ),
      floatingActionButton: centers.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _addCenter,
              backgroundColor: hammerYellow,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('신규 센터 등록'),
            )
          : null,
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_city_outlined,
                size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('등록된 센터가 없습니다',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text('우상단 + 버튼으로 센터를 등록하세요',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
      );

  void _addCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MoveLensSetupScreen(isNew: true),
      ),
    );
    setState(() {});
  }

  void _showCenterBottomSheet(MoveLensCenter center) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CenterActionSheet(
        center: center,
        onEdit: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  MoveLensSetupScreen(isNew: false, center: center),
            ),
          ).then((_) => setState(() {}));
        },
        onMeasure: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MoveLensSessionScreen(center: center),
            ),
          ).then((_) => setState(() {}));
        },
        onDashboard: () {
          Navigator.pop(context);
          final session = center.lastCompletedSession;
          if (session == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('완료된 측정 세션이 없습니다. 측정을 먼저 실행하세요.')),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  MoveLensDashboardScreen(center: center, session: session),
            ),
          );
        },
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(center);
        },
      ),
    );
  }

  void _confirmDelete(MoveLensCenter center) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('센터 삭제'),
        content: Text('"${center.name}"을 삭제하시겠습니까?\n모든 측정 데이터가 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _svc.deleteCenter(center.id);
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────

class _CenterCard extends StatelessWidget {
  final MoveLensCenter center;
  final VoidCallback onTap;

  const _CenterCard({required this.center, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasActive = center.activeSession != null;
    final sessionCount = center.sessions.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasActive
                          ? Colors.green.shade100
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasActive
                          ? Icons.radio_button_checked
                          : Icons.factory_outlined,
                      color: hasActive ? Colors.green : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          center.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (center.clientName.isNotEmpty)
                          Text(
                            center.clientName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (hasActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '측정 중',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat(Icons.place_outlined, '${center.zones.length}개 Zone'),
                  const SizedBox(width: 16),
                  _stat(Icons.tag, '${center.tagMappings.length}개 태그'),
                  const SizedBox(width: 16),
                  _stat(Icons.history, '$sessionCount회 측정'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      );
}

// ────────────────────────────────────────────────────

class _CenterActionSheet extends StatelessWidget {
  final MoveLensCenter center;
  final VoidCallback onEdit, onMeasure, onDashboard, onDelete;

  const _CenterActionSheet({
    required this.center,
    required this.onEdit,
    required this.onMeasure,
    required this.onDashboard,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(center.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            if (center.clientName.isNotEmpty)
              Text(center.clientName,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('설정 편집'),
              onTap: onEdit,
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline,
                  color: Colors.green),
              title: const Text('측정 시작/관리'),
              onTap: onMeasure,
            ),
            ListTile(
              leading:
                  const Icon(Icons.bar_chart, color: Colors.blue),
              title: const Text('분석 및 리포트'),
              onTap: onDashboard,
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('센터 삭제',
                  style: TextStyle(color: Colors.red)),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
