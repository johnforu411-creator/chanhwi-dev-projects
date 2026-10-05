import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import '../shared/ui.dart';

class RehabSessionScreen extends StatefulWidget {
  const RehabSessionScreen({super.key, required this.controller, this.initialIndex = 0});
  final AppController controller;
  final int initialIndex;

  @override
  State<RehabSessionScreen> createState() => _RehabSessionScreenState();
}

class _RehabSessionScreenState extends State<RehabSessionScreen> {
  Timer? timer;
  int secondsLeft = 0;
  int exerciseIndex = 0;

  @override
  void initState() {
    super.initState();
    exerciseIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final exercises = widget.controller.activeExercises;
      if (widget.controller.activeSessionId == null || exercises.isEmpty) {
        return Scaffold(appBar: AppBar(title: const Text('재활 세션')), body: const Center(child: Text('진행할 재활 운동이 없습니다.')));
      }
      exerciseIndex = exerciseIndex.clamp(0, exercises.length - 1);
      final active = exercises[exerciseIndex];
      final exercise = active.exercise;
      final pendingIndex = active.sets.indexWhere((set) => !set.completed);
      final allDone = exercises.every((item) => item.sets.every((set) => set.completed));
      final set = pendingIndex >= 0 ? active.sets[pendingIndex] : null;
      final completedCount = exercises.fold<int>(0, (sum, item) => sum + item.sets.where((set) => set.completed).length);
      final totalCount = exercises.fold<int>(0, (sum, item) => sum + item.sets.length);

      return Scaffold(
        appBar: AppBar(title: const Text('재활 따라하기'), actions: [TextButton(onPressed: _finish, child: const Text('마치기'))]),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
          LinearProgressIndicator(value: totalCount == 0 ? 0 : completedCount / totalCount, minHeight: 7, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 8),
          Text('운동 ${exerciseIndex + 1}/${exercises.length} · 완료 $completedCount/$totalCount세트', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (exercise.imageAsset != null) ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset(exercise.imageAsset!, height: 210, fit: BoxFit.cover)),
          const SizedBox(height: 16),
          Text(exercise.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text(exercise.englishName, style: Theme.of(context).textTheme.bodyMedium),
          if (exercise.primaryMuscle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('주요 부위 · ${exercise.primaryMuscle}')),
          if (exercise.purpose.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(exercise.purpose))),
          const SizedBox(height: 8),
          const Text('진행 방법', style: TextStyle(fontWeight: FontWeight.w800)),
          ...exercise.instructions.asMap().entries.map((entry) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 14, child: Text('${entry.key + 1}')), title: Text(entry.value))),
          if (exercise.cues.isNotEmpty) Card(color: Theme.of(context).colorScheme.secondaryContainer, child: Padding(padding: const EdgeInsets.all(14), child: Text('기억할 점\n${exercise.cues.map((cue) => '• $cue').join('\n')}'))),
          if (exercise.mistakes.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(14), child: Text('피할 동작\n${exercise.mistakes.map((mistake) => '• $mistake').join('\n')}'))),
          Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(14), child: Text(exercise.painGuide))),
          const SizedBox(height: 12),
          if (allDone)
            FilledButton.icon(onPressed: _finish, icon: const Icon(Icons.check_circle), label: const Padding(padding: EdgeInsets.all(12), child: Text('재활 마치고 통증 기록')))
          else if (set != null)
            _setAction(active, pendingIndex, set)
          else
            OutlinedButton.icon(onPressed: _nextExercise(exercises), icon: const Icon(Icons.skip_next), label: const Text('다음 운동으로')),
          if (exerciseIndex > 0 || exerciseIndex < exercises.length - 1) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: exerciseIndex == 0 ? null : () => setState(() => exerciseIndex--), icon: const Icon(Icons.chevron_left), label: const Text('이전 운동'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: exerciseIndex >= exercises.length - 1 ? null : () => setState(() => exerciseIndex++), icon: const Icon(Icons.chevron_right), label: const Text('다음 운동'))),
            ]),
          ],
        ]),
      );
    },
  );

  VoidCallback _nextExercise(List<ActiveWorkoutExercise> exercises) => () {
    if (exerciseIndex < exercises.length - 1) setState(() => exerciseIndex++);
  };

  Widget _setAction(ActiveWorkoutExercise active, int setIndex, WorkoutSetData set) {
    final timed = active.exercise.isTimed;
    if (timed) {
      if (timer != null) {
        return Column(children: [
          Text('$secondsLeft초', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          const Text('편하게 호흡하면서 정해진 힘만 유지하세요.'),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: set.durationSec == 0 ? 0 : (set.durationSec - secondsLeft) / set.durationSec, minHeight: 8, borderRadius: BorderRadius.circular(8)),
          TextButton(onPressed: _cancelTimer, child: const Text('타이머 취소')),
        ]);
      }
      return SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: () => _startTimer(active, setIndex, set),
        icon: const Icon(Icons.play_arrow),
        label: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('${set.setNumber}세트 시작 · ${set.durationSec}초')),
      ));
    }
    return Column(children: [
      Text('${set.setNumber}세트 · ${set.reps}회', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _completeSet(active, setIndex, set), icon: const Icon(Icons.check), label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('세트 완료')))),
    ]);
  }

  void _startTimer(ActiveWorkoutExercise active, int index, WorkoutSetData set) {
    timer?.cancel();
    setState(() => secondsLeft = set.durationSec);
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsLeft <= 1) {
        timer.cancel();
        this.timer = null;
        _completeSet(active, index, set);
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  void _cancelTimer() {
    timer?.cancel();
    timer = null;
    setState(() => secondsLeft = 0);
  }

  Future<void> _completeSet(ActiveWorkoutExercise active, int index, WorkoutSetData set) async {
    timer?.cancel();
    timer = null;
    await widget.controller.updateSet(exerciseIndex, index, set.copyWith(completed: true));
    if (!mounted) return;
    final current = widget.controller.activeExercises[exerciseIndex];
    final exerciseDone = current.sets.every((item) => item.completed);
    if (exerciseDone && exerciseIndex < widget.controller.activeExercises.length - 1) {
      setState(() => exerciseIndex++);
    } else {
      setState(() => secondsLeft = 0);
    }
  }

  Future<void> _finish() async {
    timer?.cancel();
    timer = null;
    final pain = await showPainDialog(context, title: '오늘 재활 중 가장 높았던 통증은?');
    if (pain == null) return;
    await widget.controller.finishWorkout(painMax: pain < 0 ? null : pain, painLocation: pain < 0 ? null : '오른쪽 어깨');
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }
}
