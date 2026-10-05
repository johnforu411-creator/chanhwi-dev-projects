import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../exercises/live_workout_screen.dart';
import '../exercises/rehab_session_screen.dart';
import '../shared/ui.dart';
import '../shared/tennis_editor.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.controller, required this.openWorkout});
  final AppController controller;
  final VoidCallback openWorkout;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Future<_TodayData> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<_TodayData> _load() async => _TodayData(
    condition: await widget.controller.db.todayCondition(),
    best: await widget.controller.db.bestExercises(),
    yesterday: await widget.controller.db.yesterdayWorkoutSummary(),
    responded: await widget.controller.db.hasTodayNextDayResponse(),
  );

  Future<void> _reload() async {
    setState(() => future = _load());
    await future;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _reload,
    child: FutureBuilder<_TodayData>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return ListView(children: const [SizedBox(height: 260), Center(child: CircularProgressIndicator())]);
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text(DateFormat('M월 d일 EEEE', 'ko').format(DateTime.now()), style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text('오늘의 몸을 읽고, 가장 좋은 한 세트를 시작하세요.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            if (widget.controller.activeSessionId != null) _activeCard(),
            if (data.yesterday != null && !data.responded) _nextDayCard(data.yesterday!),
            _startCard(data.condition),
            const SectionTitle('빠른 기록'),
            Row(children: [
              Expanded(child: _QuickAction(icon: Icons.healing, label: '통증', onTap: _pain)),
              Expanded(child: _QuickAction(icon: Icons.local_hospital_outlined, label: '치료', onTap: _treatment)),
              Expanded(child: _QuickAction(icon: Icons.sports_tennis, label: '테니스', onTap: _tennis)),
            ]),
            const SectionTitle('Shoulder BEST 6'),
            ...data.best.map((exercise) => _rehabTile(exercise)),
          ],
        );
      },
    ),
  );

  Widget _activeCard() => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: const CircleAvatar(child: Icon(Icons.play_arrow_rounded)),
      title: const Text('진행 중인 운동', style: TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${widget.controller.activeExercises.length}개 운동 · 이어서 기록하세요'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveWorkoutScreen(controller: widget.controller))),
    ),
  );

  Widget _nextDayCard(String summary) => Card(
    color: Theme.of(context).colorScheme.tertiaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('어제 운동 후, 오늘 어깨 반응은?', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [ButtonSegment(value: -1, label: Text('나쁨')), ButtonSegment(value: 0, label: Text('같음')), ButtonSegment(value: 1, label: Text('좋음'))],
          emptySelectionAllowed: true,
          selected: const {},
          onSelectionChanged: (value) async { await widget.controller.db.saveNextDayResponse(value.first, summary); await _reload(); },
        ),
      ]),
    ),
  );

  Widget _startCard(Map<String, Object?>? condition) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bolt, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(condition == null ? '컨디션을 기록하고 시작' : '오늘 컨디션 · ${condition['condition']} / 통증 ${condition['pain_level']}', style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: widget.openWorkout, icon: const Icon(Icons.fitness_center), label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('운동 시작')))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _quickRehab, icon: const Icon(Icons.accessibility_new), label: const Text('BEST 6 빠른 재활'))),
      ]),
    ),
  );

  Widget _rehabTile(Exercise exercise) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: ClipRRect(borderRadius: BorderRadius.circular(12), child: exercise.imageAsset == null ? const SizedBox(width: 58, height: 58, child: Icon(Icons.accessibility_new)) : Image.asset(exercise.imageAsset!, width: 58, height: 58, fit: BoxFit.cover)),
      title: Text('${exercise.bestPriority}. ${exercise.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(exercise.isTimed ? '${exercise.defaultSets}세트 × ${exercise.defaultDurationSec}초' : '${exercise.defaultSets}세트 × ${exercise.defaultReps}회'),
      trailing: IconButton(icon: const Icon(Icons.add_circle), onPressed: () => _addAndOpen(exercise)),
    ),
  );

  Future<void> _quickRehab() async {
    final routines = await widget.controller.db.routines();
    final routine = routines.where((r) => r.name.contains('BEST')).first;
    await widget.controller.startRoutine(routine.id);
    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => RehabSessionScreen(controller: widget.controller)));
  }

  Future<void> _addAndOpen(Exercise exercise) async {
    await widget.controller.addExercise(exercise);
    if (!mounted) return;
    if (exercise.isRehab) {
      final index = widget.controller.activeExercises.indexWhere((item) => item.exercise.id == exercise.id);
      Navigator.push(context, MaterialPageRoute(builder: (_) => RehabSessionScreen(controller: widget.controller, initialIndex: index < 0 ? 0 : index)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => LiveWorkoutScreen(controller: widget.controller)));
    }
  }

  Future<void> _pain() async {
    final value = await showPainDialog(context);
    if (value != null) { await widget.controller.recordPain(level: value, location: '오른쪽 어깨'); await _reload(); }
  }

  Future<void> _treatment() async {
    final hospital = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('치료 기록'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: hospital, decoration: const InputDecoration(labelText: '병원/기관')), const SizedBox(height: 8), TextField(controller: note, decoration: const InputDecoration(labelText: '치료 내용'))]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('저장'))],
    ));
    if (ok == true) { await widget.controller.db.saveTreatment(date: DateTime.now(), hospital: hospital.text, type: '재활치료', note: note.text); await _reload(); }
  }

  Future<void> _tennis() async {
    final draft = await showTennisEditor(context, initialDate: DateTime.now());
    if (draft == null) return;
    await widget.controller.db.saveTennis(date: draft.date, minutes: draft.minutes, intensity: draft.intensity, kind: draft.kind, served: draft.served, pain: draft.pain, note: draft.note);
    await _reload();
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Column(children: [Icon(icon), const SizedBox(height: 8), Text(label)]))));
}

class _TodayData {
  const _TodayData({required this.condition, required this.best, required this.yesterday, required this.responded});
  final Map<String, Object?>? condition; final List<Exercise> best; final String? yesterday; final bool responded;
}
