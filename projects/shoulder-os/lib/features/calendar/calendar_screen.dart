import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../shared/tennis_editor.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = DateTime.now();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CalendarDayData>>(
    future: widget.controller.db.calendarMonth(month),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final byDay = {for (final item in snapshot.data!) item.date.day: item};
      return ListView(padding: const EdgeInsets.fromLTRB(12, 6, 12, 30), children: [
        Row(children: [IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)), Expanded(child: Text(DateFormat('yyyy년 M월').format(month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right))]),
        Row(children: [for (final day in const ['월','화','수','목','금','토','일']) Expanded(child: Padding(padding: const EdgeInsets.all(8), child: Text(day, textAlign: TextAlign.center)))]),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: .82),
          itemBuilder: (context, index) {
            final offset = DateTime(month.year, month.month, 1).weekday - 1;
            final date = DateTime(month.year, month.month, index - offset + 1);
            final current = date.month == month.month;
            final data = current ? byDay[date.day] : null;
            final isSelected = _same(date, selected);
            return InkWell(onTap: () => setState(() => selected = date), borderRadius: BorderRadius.circular(12), child: Container(
              margin: const EdgeInsets.all(2), padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null, borderRadius: BorderRadius.circular(12), border: Border.all(color: data?.hasEvents == true ? Theme.of(context).colorScheme.primary.withValues(alpha: .35) : Colors.transparent)),
              child: Column(children: [Text('${date.day}', style: TextStyle(color: current ? null : Theme.of(context).disabledColor, fontWeight: isSelected ? FontWeight.w800 : null)), const Spacer(), if (data != null) Wrap(spacing: 1, runSpacing: 1, children: [if (data.weightCount > 0) const Text('🏋', style: TextStyle(fontSize: 11)), if (data.rehabCount > 0) const Text('🦴', style: TextStyle(fontSize: 11)), if (data.tennisCount > 0) const Text('🎾', style: TextStyle(fontSize: 11)), if (data.treatmentCount > 0) const Text('🏥', style: TextStyle(fontSize: 11)), if (data.painCount > 0) const Text('●', style: TextStyle(fontSize: 10, color: Colors.orange))])]),
            ));
          },
        ),
        const Divider(height: 28),
        Row(children: [
          Expanded(child: Text(DateFormat('M월 d일 EEEE', 'ko').format(selected), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          FilledButton.tonalIcon(onPressed: _addTennis, icon: const Icon(Icons.sports_tennis), label: const Text('테니스 기록')),
        ]),
        FutureBuilder<List<Map<String, String>>>(future: widget.controller.db.eventsForDate(selected), builder: (context, events) {
          if (!events.hasData) return const LinearProgressIndicator();
          if (events.data!.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: Text('기록이 없습니다.')));
          return Column(children: events.data!.map((event) => Card(child: ListTile(
            title: Text(event['title']!),
            subtitle: Text(event['detail']!),
            trailing: event['kind'] == 'tennis' ? PopupMenuButton<String>(
              onSelected: (action) => action == 'edit' ? _editTennis(event) : _deleteTennis(event),
              itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('수정')), PopupMenuItem(value: 'delete', child: Text('삭제'))],
            ) : null,
          ))).toList());
        }),
      ]);
    },
  );

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _addTennis() async {
    final draft = await showTennisEditor(context, initialDate: selected);
    if (draft == null) return;
    await widget.controller.db.saveTennis(date: draft.date, minutes: draft.minutes, intensity: draft.intensity, kind: draft.kind, served: draft.served, pain: draft.pain, note: draft.note);
    setState(() { selected = draft.date; month = DateTime(draft.date.year, draft.date.month); });
  }

  Future<void> _editTennis(Map<String, String> event) async {
    final id = int.tryParse(event['id'] ?? '');
    if (id == null) return;
    final initial = <String, Object?>{
      'session_date': event['session_date'],
      'duration_minutes': int.tryParse(event['duration_minutes'] ?? '') ?? 60,
      'intensity': int.tryParse(event['intensity'] ?? '') ?? 3,
      'session_kind': event['session_kind'] ?? '연습',
      'served': int.tryParse(event['served'] ?? '') ?? 0,
      'shoulder_pain': int.tryParse(event['shoulder_pain'] ?? ''),
      'note': event['note'] ?? '',
    };
    final draft = await showTennisEditor(context, initialDate: selected, initial: initial);
    if (draft == null) return;
    await widget.controller.db.updateTennis(id: id, date: draft.date, minutes: draft.minutes, intensity: draft.intensity, kind: draft.kind, served: draft.served, pain: draft.pain, note: draft.note);
    setState(() { selected = draft.date; month = DateTime(draft.date.year, draft.date.month); });
  }

  Future<void> _deleteTennis(Map<String, String> event) async {
    final id = int.tryParse(event['id'] ?? '');
    if (id == null) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('테니스 기록 삭제'),
      content: const Text('이 기록을 캘린더와 분석에서 삭제할까요?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제'))],
    ));
    if (confirmed != true) return;
    await widget.controller.db.deleteTennis(id);
    setState(() {});
  }
}
