import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))), ?action]),
  );
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, required this.icon, this.tint});
  final String label;
  final String value;
  final IconData icon;
  final Color? tint;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: tint ?? Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]),
    ),
  );
}

Future<int?> showPainDialog(BuildContext context, {String title = '현재 통증은 어떤가요?'}) async {
  var value = 0.0;
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${value.round()} / 10', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        Slider(value: value, max: 10, divisions: 10, label: value.round().toString(), onChanged: (v) => setState(() => value = v)),
        Text(value <= 3 ? '진행 가능 범위' : value == 4 ? '강도와 가동범위를 줄이세요' : '운동을 멈추고 상태를 확인하세요'),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('돌아가기')),
        TextButton(onPressed: () => Navigator.pop(context, -1), child: const Text('통증 기록 없이 종료')),
        FilledButton(onPressed: () => Navigator.pop(context, value.round()), child: const Text('기록')),
      ],
    )),
  );
}
