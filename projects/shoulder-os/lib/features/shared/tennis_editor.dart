import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TennisDraft {
  const TennisDraft({
    required this.date,
    required this.minutes,
    required this.intensity,
    required this.kind,
    required this.served,
    required this.pain,
    required this.note,
  });

  final DateTime date;
  final int minutes;
  final int intensity;
  final String kind;
  final bool served;
  final int? pain;
  final String note;
}

Future<TennisDraft?> showTennisEditor(
  BuildContext context, {
  required DateTime initialDate,
  Map<String, Object?>? initial,
}) => showModalBottomSheet<TennisDraft>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _TennisEditor(initialDate: initialDate, initial: initial),
);

class _TennisEditor extends StatefulWidget {
  const _TennisEditor({required this.initialDate, this.initial});
  final DateTime initialDate;
  final Map<String, Object?>? initial;

  @override
  State<_TennisEditor> createState() => _TennisEditorState();
}

class _TennisEditorState extends State<_TennisEditor> {
  late DateTime date = _date(widget.initial?['session_date']) ?? widget.initialDate;
  late double minutes = ((widget.initial?['duration_minutes'] as num?) ?? 60).toDouble().clamp(10, 180);
  late int intensity = ((widget.initial?['intensity'] as num?) ?? 3).toInt().clamp(1, 5);
  late String kind = (widget.initial?['session_kind'] as String?) ?? '연습';
  late bool served = ((widget.initial?['served'] as num?) ?? 1) == 1;
  late double pain = ((widget.initial?['shoulder_pain'] as num?) ?? 0).toDouble();
  late bool trackPain = widget.initial?['shoulder_pain'] != null;
  late final TextEditingController note = TextEditingController(text: (widget.initial?['note'] as String?) ?? '');

  DateTime? _date(Object? value) {
    if (value is! String || value.length < 10) return null;
    return DateTime.tryParse(value.substring(0, 10));
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.initial == null ? '테니스 기록' : '테니스 기록 수정', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today), title: const Text('날짜'), subtitle: Text(DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date)), trailing: const Icon(Icons.edit_calendar), onTap: _pickDate),
        const SizedBox(height: 8),
        Text('플레이 시간 · ${minutes.round()}분'),
        Slider(value: minutes, min: 10, max: 180, divisions: 34, label: '${minutes.round()}분', onChanged: (value) => setState(() => minutes = value)),
        const SizedBox(height: 6),
        const Text('강도'),
        const SizedBox(height: 8),
        SegmentedButton<int>(segments: List.generate(5, (index) => ButtonSegment(value: index + 1, label: Text('${index + 1}'))), selected: {intensity}, onSelectionChanged: (value) => setState(() => intensity = value.first)),
        const SizedBox(height: 14),
        const Text('세션 종류'),
        const SizedBox(height: 8),
        SegmentedButton<String>(segments: const [ButtonSegment(value: '연습', label: Text('연습')), ButtonSegment(value: '게임', label: Text('게임')), ButtonSegment(value: '레슨', label: Text('레슨'))], selected: {kind}, onSelectionChanged: (value) => setState(() => kind = value.first)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('서브 포함'), value: served, onChanged: (value) => setState(() => served = value)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('어깨 통증 함께 기록'), subtitle: const Text('테니스 후 어깨 반응과 연결합니다.'), value: trackPain, onChanged: (value) => setState(() => trackPain = value)),
        if (trackPain) ...[
          Text('테니스 중 어깨 통증 · ${pain.round()}/10'),
          Slider(value: pain, min: 0, max: 10, divisions: 10, label: pain.round().toString(), onChanged: (value) => setState(() => pain = value)),
        ],
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: '메모', hintText: '서브 복귀, 어깨 느낌 등')),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: Text(widget.initial == null ? '기록 저장' : '수정 저장'))),
      ])),
    ),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2015), lastDate: DateTime(2100));
    if (picked != null) setState(() => date = picked);
  }

  void _save() => Navigator.pop(context, TennisDraft(
    date: date,
    minutes: minutes.round(),
    intensity: intensity,
    kind: kind,
    served: served,
    pain: trackPain ? pain.round() : null,
    note: note.text.trim(),
  ));
}
