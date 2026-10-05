import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../shared/ui.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int days = 28;
  @override
  Widget build(BuildContext context) => FutureBuilder<AnalyticsData>(
    future: widget.controller.db.analytics(days: days),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final data = snapshot.data!;
      return ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<int>(segments: const [ButtonSegment(value: 7, label: Text('7일')), ButtonSegment(value: 28, label: Text('4주')), ButtonSegment(value: 90, label: Text('3개월'))], selected: {days}, onSelectionChanged: (value) => setState(() => days = value.first)),
        const SectionTitle('훈련 요약'),
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.35, children: [
          MetricTile(label: '완료한 운동', value: '${data.workouts}회', icon: Icons.fitness_center),
          MetricTile(label: '운동 시간', value: '${data.minutes}분', icon: Icons.timer_outlined),
          MetricTile(label: '완료 세트', value: '${data.sets}세트', icon: Icons.check_circle_outline),
          MetricTile(label: '총 볼륨', value: '${data.volume.round()}kg', icon: Icons.monitor_weight_outlined),
        ]),
        const SectionTitle('어깨 회복'),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
          _line('재활 세션', '${data.rehabSessions}회'),
          _line('테니스', '${data.tennisSessions}회'),
          _line('평균 통증', data.averagePain.toStringAsFixed(1)),
          _line('최대 통증', '${data.maxPain}/10'),
          _line('다음날 반응', data.nextDayAverage > .2 ? '좋아지는 추세' : data.nextDayAverage < -.2 ? '주의 필요' : '유지'),
        ]))),
        const SizedBox(height: 12),
        Card(color: data.maxPain >= 5 ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Text(data.maxPain >= 5 ? '최근 높은 통증 기록이 있습니다. BEST 6은 통증 없는 범위에서 수행하고, 증상이 이어지면 전문가와 상의하세요.' : '통증과 다음날 반응을 함께 보면 운동량을 안전하게 조절하기 쉽습니다.'))),
      ]);
    },
  );

  Widget _line(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]));
}
