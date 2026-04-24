import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../constants.dart';
import '../../models/movelens_center.dart';
import '../../models/movelens_session.dart';
import '../../services/movelens_service.dart';

class MoveLensDashboardScreen extends StatefulWidget {
  final MoveLensCenter center;
  final MoveLensSession session;

  const MoveLensDashboardScreen({
    super.key,
    required this.center,
    required this.session,
  });

  @override
  State<MoveLensDashboardScreen> createState() =>
      _MoveLensDashboardScreenState();
}

class _MoveLensDashboardScreenState extends State<MoveLensDashboardScreen> {
  late MoveLensAnalysis _analysis;
  bool _generatingPdf = false;

  // 비용 분석 입력값
  double _hourlyRate = 15000; // 시급 (원)
  int _workingDaysPerYear = 250;

  @override
  void initState() {
    super.initState();
    _analysis = MoveLensService.instance
        .analyzeSession(widget.center, widget.session);
  }

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}시간 ${d.inMinutes % 60}분';
    }
    return '${d.inMinutes}분 ${d.inSeconds % 60}초';
  }

  double get _annualMovementCost {
    final movementHours =
        _analysis.totalMovementTime.inSeconds / 3600.0;
    return movementHours * _hourlyRate * _workingDaysPerYear;
  }

  Future<void> _generatePdf() async {
    setState(() => _generatingPdf = true);
    try {
      final pdf = _buildPdf();
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'MoveLens_${widget.center.name}_리포트.pdf',
      );
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  pw.Document _buildPdf() {
    final doc = pw.Document();
    final a = _analysis;
    final center = widget.center;
    final session = widget.session;

    final dateStr =
        '${session.startTime.year}.${session.startTime.month.toString().padLeft(2, '0')}.${session.startTime.day.toString().padLeft(2, '0')}';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        // ── 표지 섹션 ──────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(24),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey900,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF1C342),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text('Move',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 18,
                          color: PdfColors.black)),
                ),
                pw.SizedBox(width: 4),
                pw.Text('Lens',
                    style: const pw.TextStyle(
                        fontSize: 18, color: PdfColors.white)),
                pw.SizedBox(width: 12),
                pw.Text('공정 생산성 진단 리포트',
                    style: const pw.TextStyle(
                        fontSize: 14, color: PdfColors.grey300)),
              ]),
              pw.SizedBox(height: 12),
              pw.Text(center.name,
                  style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              if (center.clientName.isNotEmpty)
                pw.Text(center.clientName,
                    style: const pw.TextStyle(
                        fontSize: 14, color: PdfColors.grey400)),
              pw.SizedBox(height: 8),
              pw.Text('측정일: $dateStr  |  측정 시간: ${_fmtDuration(session.elapsed)}',
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.grey400)),
            ],
          ),
        ),
        pw.SizedBox(height: 24),

        // ── 핵심 KPI ───────────────────────────────────────
        _pdfSection('핵심 KPI'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _pdfCell('지표', bold: true),
                _pdfCell('값', bold: true),
              ],
            ),
            pw.TableRow(children: [
              _pdfCell('총 이동 건수'),
              _pdfCell('${a.totalTrips}건'),
            ]),
            pw.TableRow(children: [
              _pdfCell('총 이동 시간'),
              _pdfCell(_fmtDuration(a.totalMovementTime)),
            ]),
            pw.TableRow(children: [
              _pdfCell('이동 공수 비율'),
              _pdfCell('${a.movementRatio.toStringAsFixed(1)}%'),
            ]),
            pw.TableRow(children: [
              _pdfCell('측정 태그 수'),
              _pdfCell('${center.tagMappings.length}개'),
            ]),
          ],
        ),
        pw.SizedBox(height: 20),

        // ── 경로별 이동 현황 ───────────────────────────────
        if (a.tripCountByRoute.isNotEmpty) ...[
          _pdfSection('경로별 이동 현황'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _pdfCell('경로', bold: true),
                  _pdfCell('이동 건수', bold: true),
                  _pdfCell('평균 이동 시간', bold: true),
                ],
              ),
              ...a.tripCountByRoute.entries.map((e) => pw.TableRow(
                    children: [
                      _pdfCell(e.key),
                      _pdfCell('${e.value}건'),
                      _pdfCell(_fmtDuration(
                          a.avgDurationByRoute[e.key] ?? Duration.zero)),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // ── 자동화 후보 경로 ───────────────────────────────
        if (a.topRoutes.isNotEmpty) ...[
          _pdfSection('자동화 후보 경로 (Top ${a.topRoutes.length})'),
          ...a.topRoutes.asMap().entries.map((e) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(children: [
                  pw.Container(
                    width: 24,
                    height: 24,
                    decoration: pw.BoxDecoration(
                      color: e.key == 0
                          ? const PdfColor.fromInt(0xFFF1C342)
                          : PdfColors.grey300,
                      shape: pw.BoxShape.circle,
                    ),
                    child: pw.Center(
                      child: pw.Text('${e.key + 1}',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                              color: PdfColors.black)),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(e.value,
                      style: const pw.TextStyle(fontSize: 13)),
                  pw.SizedBox(width: 8),
                  pw.Text(
                      '(${a.tripCountByRoute[e.value] ?? 0}건)',
                      style: const pw.TextStyle(
                          fontSize: 12, color: PdfColors.grey600)),
                ]),
              )),
          pw.SizedBox(height: 20),
        ],

        // ── AS-IS 비용 분석 ────────────────────────────────
        _pdfSection('AS-IS 이동 공수 비용 분석'),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.orange50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.orange200),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                  '연간 이동 공수 비용 (추정): ${_formatWon(_annualMovementCost)}',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFFE65100))),
              pw.SizedBox(height: 8),
              pw.Text(
                  '산출 기준: 이동 시간 ${_fmtDuration(a.totalMovementTime)} × 시급 ${_formatWon(_hourlyRate.toDouble())} × 연간 $_workingDaysPerYear일',
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text('※ AMR 도입 시 해당 비용의 이동공수 ${a.movementRatio.toStringAsFixed(1)}% 절감 가능',
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey700)),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // 푸터
        pw.Divider(),
        pw.SizedBox(height: 8),
        pw.Text(
            'Generated by MoveLens  |  ${DateTime.now().year}.${DateTime.now().month}.${DateTime.now().day}',
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColors.grey500)),
      ],
    ));

    return doc;
  }

  pw.Widget _pdfSection(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey900)),
            pw.Container(height: 2, color: const PdfColor.fromInt(0xFFF1C342)),
            pw.SizedBox(height: 6),
          ],
        ),
      );

  pw.Widget _pdfCell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  String _formatWon(double amount) {
    if (amount >= 100000000) {
      return '${(amount / 100000000).toStringAsFixed(1)}억원';
    } else if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(0)}만원';
    }
    return '${amount.toStringAsFixed(0)}원';
  }

  @override
  Widget build(BuildContext context) {
    final a = _analysis;
    final hasData = a.totalTrips > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.center.name),
            Text(
              '분석 결과',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          if (_generatingPdf)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: hasData ? _generatePdf : null,
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              label: const Text('리포트 생성',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: hasData ? _buildDashboard(a) : _buildEmpty(),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('분석 데이터가 없습니다',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'From-To Rule과 Zone이 설정된 상태에서\n측정을 실행하면 데이터가 수집됩니다',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildDashboard(MoveLensAnalysis a) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핵심 KPI 카드들
          _sectionTitle('핵심 KPI'),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _kpiCard('총 이동 건수', '${a.totalTrips}건',
                  Icons.directions_walk, Colors.blue),
              _kpiCard('이동 공수 비율',
                  '${a.movementRatio.toStringAsFixed(1)}%',
                  Icons.pie_chart_outline, Colors.orange),
              _kpiCard('총 이동 시간', _fmtDuration(a.totalMovementTime),
                  Icons.timer_outlined, Colors.green),
              _kpiCard('대기 시간', _fmtDuration(a.totalIdleTime),
                  Icons.hourglass_empty, Colors.grey),
            ],
          ),
          const SizedBox(height: 20),

          // 경로별 이동 현황
          if (a.tripCountByRoute.isNotEmpty) ...[
            _sectionTitle('경로별 이동 현황'),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  // 바 차트
                  _RouteBarChart(
                    routes: a.tripCountByRoute,
                    avgDurations: a.avgDurationByRoute,
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 자동화 후보 경로
          if (a.topRoutes.isNotEmpty) ...[
            _sectionTitle('자동화 후보 경로 (Top ${a.topRoutes.length})'),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: a.topRoutes.asMap().entries.map((e) {
                    final count = a.tripCountByRoute[e.value] ?? 0;
                    final avg = a.avgDurationByRoute[e.value];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: e.key == 0
                            ? hammerYellow
                            : Colors.grey.shade300,
                        radius: 14,
                        child: Text('${e.key + 1}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black)),
                      ),
                      title: Text(e.value,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: avg != null
                          ? Text(
                              '평균 ${_fmtDuration(avg)}  |  $count건',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12))
                          : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$count건',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // AS-IS 비용 분석
          _sectionTitle('AS-IS 이동 공수 비용 분석'),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('시급 (원)',
                              style: TextStyle(fontSize: 12)),
                          Slider(
                            value: _hourlyRate,
                            min: 5000,
                            max: 50000,
                            divisions: 90,
                            label: _formatWon(_hourlyRate),
                            onChanged: (v) =>
                                setState(() => _hourlyRate = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('연간 근무일 (일)',
                              style: TextStyle(fontSize: 12)),
                          Slider(
                            value: _workingDaysPerYear.toDouble(),
                            min: 100,
                            max: 365,
                            divisions: 265,
                            label: '$_workingDaysPerYear일',
                            onChanged: (v) => setState(
                                () => _workingDaysPerYear = v.round()),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '연간 이동 공수 비용 (추정)',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatWon(_annualMovementCost),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '이동공수 비율 ${a.movementRatio.toStringAsFixed(1)}% → AMR 도입 시 절감 가능',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style:
          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));

  Widget _kpiCard(String label, String value, IconData icon, Color color) =>
      Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 11)),
                    Text(value,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ────────────────────────────────────────────────────

class _RouteBarChart extends StatelessWidget {
  final Map<String, int> routes;
  final Map<String, Duration> avgDurations;

  const _RouteBarChart({required this.routes, required this.avgDurations});

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) return const SizedBox.shrink();
    final maxCount =
        routes.values.reduce((a, b) => a > b ? a : b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('경로별 이동 건수',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        CustomPaint(
          painter: _BarChartPainter(routes: routes, maxCount: maxCount),
          size: Size(double.infinity, routes.length * 40.0 + 20),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final Map<String, int> routes;
  final double maxCount;

  _BarChartPainter({required this.routes, required this.maxCount});

  @override
  void paint(Canvas canvas, Size size) {
    final barHeight = 24.0;
    final rowHeight = 40.0;
    final labelWidth = size.width * 0.4;
    final chartWidth = size.width * 0.55;
    final chartLeft = labelWidth + 4;

    final colors = [
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFF44336),
    ];

    int i = 0;
    for (final entry in routes.entries) {
      final y = i * rowHeight;
      final barW = maxCount > 0 ? (entry.value / maxCount) * chartWidth : 0.0;
      final color = colors[i % colors.length];

      // 바 배경
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(chartLeft, y + (rowHeight - barHeight) / 2,
              chartWidth, barHeight),
          const Radius.circular(4),
        ),
        Paint()..color = color.withValues(alpha: 0.1),
      );

      // 바
      if (barW > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(chartLeft, y + (rowHeight - barHeight) / 2,
                barW, barHeight),
            const Radius.circular(4),
          ),
          Paint()..color = color.withValues(alpha: 0.8),
        );
      }

      // 라벨
      final tp = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: const TextStyle(fontSize: 11, color: Colors.black87),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: labelWidth - 4);
      tp.paint(canvas,
          Offset(0, y + (rowHeight - tp.height) / 2));

      // 건수
      final countTp = TextPainter(
        text: TextSpan(
          text: '${entry.value}건',
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      countTp.paint(
          canvas,
          Offset(
              chartLeft + barW + 4,
              y + (rowHeight - countTp.height) / 2));

      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.routes != routes;
}
