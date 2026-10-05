import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../exercises/live_workout_screen.dart';
import '../exercises/rehab_session_screen.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  late Future<List<RoutineInfo>> future = widget.controller.db.routines();
  void reload() => setState(() => future = widget.controller.db.routines());

  @override
  Widget build(BuildContext context) => FutureBuilder<List<RoutineInfo>>(
    future: future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(padding: EdgeInsets.all(18), child: Row(children: [Icon(Icons.auto_awesome), SizedBox(width: 12), Expanded(child: Text('목적에 맞는 순서를 저장하고 한 번에 시작하세요. BEST 6 재활 루틴은 바로 사용할 수 있습니다.', style: TextStyle(fontWeight: FontWeight.w700)))])),
          ),
          const SizedBox(height: 10),
          ...snapshot.data!.map(_card),
          OutlinedButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('새 루틴 만들기')),
        ],
      );
    },
  );

  Widget _card(RoutineInfo routine) => Card(child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [CircleAvatar(child: Icon(routine.category == '재활' ? Icons.accessibility_new : Icons.fitness_center)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(routine.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), Text('${routine.exerciseCount}개 운동 · 약 ${routine.estimatedMinutes}분 · ${routine.category}')]))]),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: FilledButton.icon(onPressed: () => _start(routine.id), icon: const Icon(Icons.play_arrow), label: const Text('시작'))), const SizedBox(width: 8), IconButton.filledTonal(onPressed: () async { await widget.controller.db.duplicateRoutine(routine.id); reload(); }, icon: const Icon(Icons.copy_outlined), tooltip: '복제')]),
    ]),
  ));

  Future<void> _start(int id) async {
    final rows = await widget.controller.db.routineExercises(id);
    await widget.controller.startRoutine(id);
    if (!mounted) return;
    final rehabOnly = rows.isNotEmpty && rows.every((row) => row['category'] == '재활');
    Navigator.push(context, MaterialPageRoute(builder: (_) => rehabOnly ? RehabSessionScreen(controller: widget.controller) : LiveWorkoutScreen(controller: widget.controller)));
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final selected = <String>{};
    final exercises = await widget.controller.db.exercises();
    if (!mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('새 루틴'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: '루틴 이름')), const SizedBox(height: 10),
        SizedBox(height: 300, child: ListView(children: exercises.map((e) => CheckboxListTile(value: selected.contains(e.id), title: Text(e.name), subtitle: Text(e.category), onChanged: (v) => setDialogState(() => v == true ? selected.add(e.id) : selected.remove(e.id)))).toList())),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')), FilledButton(onPressed: selected.isEmpty ? null : () => Navigator.pop(context, true), child: const Text('저장'))],
    )));
    if (ok == true) { await widget.controller.db.createRoutine(name.text.trim().isEmpty ? '나의 루틴' : name.text.trim(), '사용자', selected.toList()); reload(); }
  }
}
