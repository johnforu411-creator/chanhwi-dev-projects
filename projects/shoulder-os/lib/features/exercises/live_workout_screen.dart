import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../shared/ui.dart';

class LiveWorkoutScreen extends StatelessWidget {
  const LiveWorkoutScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(controller.activeSessionType == 'rehab' ? '재활 진행 중' : '운동 기록'),
        actions: [TextButton(onPressed: controller.activeSessionId == null ? null : () => _finish(context), child: const Text('완료'))],
      ),
      body: controller.activeSessionId == null
          ? const Center(child: Text('진행 중인 운동이 없습니다.'))
          : Column(children: [
              if (controller.restSecondsRemaining > 0) _RestTimer(controller: controller),
              Expanded(child: controller.activeExercises.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('운동 탭에서 종목을 추가하세요.', textAlign: TextAlign.center)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                    itemCount: controller.activeExercises.length,
                    itemBuilder: (context, index) => _ExerciseCard(controller: controller, exerciseIndex: index),
                  )),
            ]),
      floatingActionButton: controller.activeSessionId == null ? null : FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context), icon: const Icon(Icons.add), label: const Text('운동 추가'),
      ),
    ),
  );

  Future<void> _finish(BuildContext context) async {
    final pain = await showPainDialog(context, title: '운동 중 최대 통증은?');
    if (pain == null) return;
    await controller.finishWorkout(painMax: pain < 0 ? null : pain, painLocation: pain < 0 ? null : '오른쪽 어깨');
    if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }
}

class _RestTimer extends StatelessWidget {
  const _RestTimer({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final seconds = controller.restSecondsRemaining;
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          const Icon(Icons.timer_outlined), const SizedBox(width: 8),
          Expanded(child: Text('휴식 ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w800))),
          TextButton(onPressed: () => controller.adjustRestTimer(-10), child: const Text('-10초')),
          TextButton(onPressed: () => controller.adjustRestTimer(10), child: const Text('+10초')),
          IconButton(onPressed: controller.stopRestTimer, icon: const Icon(Icons.close)),
        ]),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.controller, required this.exerciseIndex});
  final AppController controller;
  final int exerciseIndex;

  @override
  Widget build(BuildContext context) {
    final item = controller.activeExercises[exerciseIndex];
    final timed = item.exercise.isTimed;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(child: Icon(item.exercise.isRehab ? Icons.accessibility_new : Icons.fitness_center)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.exercise.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), Text(item.exercise.category, style: Theme.of(context).textTheme.bodySmall)])),
          ]),
          if (item.exercise.trackShoulderPain) Padding(padding: const EdgeInsets.only(top: 10), child: Text(item.exercise.painGuide, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12))),
          const SizedBox(height: 10),
          Row(children: [const SizedBox(width: 38, child: Text('세트', textAlign: TextAlign.center)), Expanded(child: Text(timed ? '시간' : '무게', textAlign: TextAlign.center)), Expanded(child: Text(timed ? '반복' : '횟수', textAlign: TextAlign.center)), const SizedBox(width: 48)]),
          ...List.generate(item.sets.length, (setIndex) => _SetRow(controller: controller, exerciseIndex: exerciseIndex, setIndex: setIndex)),
          Center(child: TextButton.icon(onPressed: () => controller.addSet(item.id), icon: const Icon(Icons.add), label: const Text('세트 추가'))),
        ]),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.controller, required this.exerciseIndex, required this.setIndex});
  final AppController controller;
  final int exerciseIndex;
  final int setIndex;

  @override
  Widget build(BuildContext context) {
    final parent = controller.activeExercises[exerciseIndex];
    final set = parent.sets[setIndex];
    final timed = parent.exercise.isTimed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 38, child: Text('${set.setNumber}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(child: _NumberButton(
          value: timed ? '${set.durationSec}초' : '${_pretty(set.weight)}kg',
          onTap: () => _number(context, first: true),
        )),
        const SizedBox(width: 6),
        Expanded(child: _NumberButton(value: '${set.reps}회', onTap: () => _number(context, first: false))),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          onPressed: () => controller.updateSet(exerciseIndex, setIndex, set.copyWith(completed: !set.completed)),
          icon: Icon(set.completed ? Icons.check : Icons.circle_outlined),
          style: IconButton.styleFrom(backgroundColor: set.completed ? Theme.of(context).colorScheme.primaryContainer : null),
        ),
      ]),
    );
  }

  String _pretty(double value) => value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);

  Future<void> _number(BuildContext context, {required bool first}) async {
    final parent = controller.activeExercises[exerciseIndex];
    final set = parent.sets[setIndex];
    final timed = parent.exercise.isTimed;
    final initial = first ? (timed ? set.durationSec.toDouble() : set.weight) : set.reps.toDouble();
    final step = first && !timed ? 2.5 : 1.0;
    final value = await showModalBottomSheet<double>(context: context, showDragHandle: true, builder: (context) => _NumberPicker(title: first ? (timed ? '시간(초)' : '무게(kg)') : '횟수', initial: initial, step: step));
    if (value == null) return;
    await controller.updateSet(exerciseIndex, setIndex, first ? (timed ? set.copyWith(durationSec: value.round()) : set.copyWith(weight: value)) : set.copyWith(reps: value.round()));
  }
}

class _NumberButton extends StatelessWidget {
  const _NumberButton({required this.value, required this.onTap});
  final String value; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => FilledButton.tonal(onPressed: onTap, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)));
}

class _NumberPicker extends StatefulWidget {
  const _NumberPicker({required this.title, required this.initial, required this.step});
  final String title; final double initial; final double step;
  @override
  State<_NumberPicker> createState() => _NumberPickerState();
}

class _NumberPickerState extends State<_NumberPicker> {
  late double value = widget.initial;
  late final TextEditingController field = TextEditingController(text: _text(value));
  String _text(double number) => number == number.roundToDouble() ? number.round().toString() : number.toStringAsFixed(1);
  void change(double next) { setState(() => value = next.clamp(0, 9999)); field.text = _text(value); }
  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(
    padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 18),
      Row(children: [IconButton.filledTonal(onPressed: () => change(value - widget.step), icon: const Icon(Icons.remove)), const SizedBox(width: 10), Expanded(child: TextField(controller: field, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall, onChanged: (text) => value = double.tryParse(text) ?? value)), const SizedBox(width: 10), IconButton.filledTonal(onPressed: () => change(value + widget.step), icon: const Icon(Icons.add))]),
      const SizedBox(height: 14), Row(children: [-widget.step * 2, -widget.step, widget.step, widget.step * 2].map((delta) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: OutlinedButton(onPressed: () => change(value + delta), child: Text('${delta > 0 ? '+' : ''}${_text(delta)}'))))).toList()),
      const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(field.text) ?? value), child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('적용')))),
    ]),
  ));
}
