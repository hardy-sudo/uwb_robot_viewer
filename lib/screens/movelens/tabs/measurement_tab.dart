import 'package:flutter/material.dart';

import '../../../models/movelens_center.dart';
import '../../../models/movelens_session.dart';
import '../../../services/movelens_service.dart';

class MoveLensMeasurementTab extends StatefulWidget {
  final MoveLensCenter center;
  final VoidCallback? onStartMeasurement;

  const MoveLensMeasurementTab({
    super.key,
    required this.center,
    this.onStartMeasurement,
  });

  @override
  State<MoveLensMeasurementTab> createState() =>
      _MoveLensMeasurementTabState();
}

class _MoveLensMeasurementTabState extends State<MoveLensMeasurementTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _svc = MoveLensService.instance;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final schedule = widget.center.schedule;
    final rules = widget.center.fromToRules;
    final zones = widget.center.zones;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 운영 시간 설정
          _SectionCard(
            title: '운영 시간 설정',
            icon: Icons.schedule,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TimeTile(
                        label: '운영 시작',
                        hour: schedule.operatingStartHour,
                        minute: schedule.operatingStartMinute,
                        onChanged: (h, m) {
                          setState(() {
                            schedule.operatingStartHour = h;
                            schedule.operatingStartMinute = m;
                          });
                          _svc.updateCenter(widget.center);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeTile(
                        label: '운영 종료',
                        hour: schedule.operatingEndHour,
                        minute: schedule.operatingEndMinute,
                        onChanged: (h, m) {
                          setState(() {
                            schedule.operatingEndHour = h;
                            schedule.operatingEndMinute = m;
                          });
                          _svc.updateCenter(widget.center);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('총 운영 시간: ${schedule.totalOperatingMinutes ~/ 60}시간 ${schedule.totalOperatingMinutes % 60}분',
                        style: TextStyle(
                            color: Colors.grey[700], fontSize: 13)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addExcludeRange,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('제외 시간 추가', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                if (schedule.excludedRanges.isNotEmpty)
                  ...schedule.excludedRanges.asMap().entries.map((e) =>
                      ListTile(
                        dense: true,
                        leading:
                            const Icon(Icons.remove_circle_outline, size: 18),
                        title: Text(e.value.label,
                            style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              schedule.excludedRanges.removeAt(e.key);
                            });
                            _svc.updateCenter(widget.center);
                          },
                        ),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // From-To Rule 설정
          _SectionCard(
            title: 'From-To 분석 구간',
            icon: Icons.route,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '분석할 이동 구간을 정의합니다. Zone이 먼저 등록되어야 합니다.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (zones.length < 2)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_outlined,
                            color: Colors.orange[700], size: 18),
                        const SizedBox(width: 8),
                        Text('맵 탭에서 Zone을 2개 이상 등록해주세요',
                            style: TextStyle(
                                color: Colors.orange[800], fontSize: 13)),
                      ],
                    ),
                  )
                else ...[
                  ...rules.asMap().entries.map((e) {
                    final r = e.value;
                    final fromZone = zones.firstWhere(
                      (z) => z.id == r.fromZoneId,
                      orElse: () =>
                          zones.first,
                    );
                    final toZone = zones.firstWhere(
                      (z) => z.id == r.toZoneId,
                      orElse: () =>
                          zones.last,
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          r.bidirectional
                              ? Icons.swap_horiz
                              : Icons.arrow_forward,
                          color: Colors.blue,
                          size: 20,
                        ),
                        title: Text(
                          '${fromZone.name}  →  ${toZone.name}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: r.bidirectional
                            ? const Text('양방향', style: TextStyle(fontSize: 11))
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () {
                            _svc.deleteFromToRule(widget.center, e.key);
                            setState(() {});
                          },
                        ),
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: _addFromToRule,
                    icon: const Icon(Icons.add_road, size: 18),
                    label: const Text('구간 추가'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 측정 시작 버튼
          _StartMeasurementCard(
            center: widget.center,
            onStart: widget.onStartMeasurement,
          ),
        ],
      ),
    );
  }

  void _addExcludeRange() async {
    TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      helpText: '제외 시작 시간',
    );
    if (start == null || !mounted) return;
    TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 13, minute: 0),
      helpText: '제외 종료 시간',
    );
    if (end == null) return;
    setState(() {
      widget.center.schedule.excludedRanges.add(TimeRange(
        startHour: start.hour,
        startMinute: start.minute,
        endHour: end.hour,
        endMinute: end.minute,
      ));
    });
    _svc.updateCenter(widget.center);
  }

  void _addFromToRule() {
    final zones = widget.center.zones;
    String fromId = zones.first.id;
    String toId = zones.length > 1 ? zones[1].id : zones.first.id;
    bool bidirectional = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('From-To 구간 추가'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: fromId,
                  decoration: const InputDecoration(
                    labelText: 'From Zone',
                    border: OutlineInputBorder(),
                  ),
                  items: zones
                      .map((z) => DropdownMenuItem(
                            value: z.id,
                            child: Text(z.name),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setS(() => fromId = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: toId,
                  decoration: const InputDecoration(
                    labelText: 'To Zone',
                    border: OutlineInputBorder(),
                  ),
                  items: zones
                      .map((z) => DropdownMenuItem(
                            value: z.id,
                            child: Text(z.name),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setS(() => toId = v);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: bidirectional,
                  onChanged: (v) => setS(() => bidirectional = v),
                  title: const Text('양방향 분석',
                      style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (fromId == toId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('From과 To Zone이 달라야 합니다')),
                  );
                  return;
                }
                _svc.addFromToRule(
                  widget.center,
                  FromToRule(
                    fromZoneId: fromId,
                    toZoneId: toId,
                    bidirectional: bidirectional,
                  ),
                );
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────

class _StartMeasurementCard extends StatelessWidget {
  final MoveLensCenter center;
  final VoidCallback? onStart;

  const _StartMeasurementCard({required this.center, this.onStart});

  bool get _canStart =>
      center.zones.length >= 2 && center.tagMappings.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _canStart ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _canStart ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _canStart
                ? Icons.play_circle_outline
                : Icons.warning_amber_outlined,
            size: 48,
            color: _canStart ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 12),
          Text(
            _canStart ? '측정 준비 완료' : '설정 미완료',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _canStart ? Colors.green[800] : Colors.orange[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _canStart
                ? 'Zone ${center.zones.length}개, 태그 ${center.tagMappings.length}개가 등록되었습니다'
                : 'Zone 2개 이상, 태그 1개 이상 등록 후 측정 가능합니다',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canStart ? onStart : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('측정 시작'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 1,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const Divider(height: 16),
              child,
            ],
          ),
        ),
      );
}

class _TimeTile extends StatelessWidget {
  final String label;
  final int hour, minute;
  final void Function(int h, int m) onChanged;

  const _TimeTile({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
          helpText: label,
        );
        if (t != null) onChanged(t.hour, t.minute);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(timeStr,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
