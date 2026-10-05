import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models.dart';
import 'live_workout_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String category = '최근';
  String query = '';
  final categories = const ['최근', '즐겨찾기', 'BEST 재활', '가슴', '등', '어깨', '팔', '하체', '코어', '재활'];

  Future<List<Exercise>> _load() => widget.controller.db.exercises(category: category, query: query);

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: TextField(
      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '운동 검색'),
      onChanged: (value) => setState(() => query = value),
    )),
    SizedBox(height: 44, child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16), scrollDirection: Axis.horizontal,
      itemCount: categories.length, separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) => ChoiceChip(label: Text(categories[i]), selected: category == categories[i], onSelected: (_) => setState(() => category = categories[i])),
    )),
    Expanded(child: FutureBuilder<List<Exercise>>(
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return const Center(child: Text('조건에 맞는 운동이 없습니다.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16), itemCount: snapshot.data!.length, separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, i) => _tile(snapshot.data![i]),
        );
      },
    )),
  ]);

  Widget _tile(Exercise exercise) => Card(child: ListTile(
    contentPadding: const EdgeInsets.fromLTRB(14, 7, 6, 7),
    leading: CircleAvatar(backgroundColor: exercise.isRehab ? Theme.of(context).colorScheme.tertiaryContainer : Theme.of(context).colorScheme.secondaryContainer, child: Icon(exercise.isRehab ? Icons.accessibility_new : Icons.fitness_center)),
    title: Text(exercise.name, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text('${exercise.category} · ${exercise.primaryMuscle}${exercise.isBest ? ' · BEST ${exercise.bestPriority}' : ''}'),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(icon: Icon(exercise.isFavorite ? Icons.star : Icons.star_border), onPressed: () async { await widget.controller.db.toggleFavorite(exercise.id, !exercise.isFavorite); setState(() {}); }),
      IconButton(icon: const Icon(Icons.add_circle), onPressed: () => _add(exercise)),
    ]),
    onTap: () => _showDetail(exercise),
  ));

  Future<void> _add(Exercise exercise) async {
    await widget.controller.addExercise(exercise);
    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => LiveWorkoutScreen(controller: widget.controller)));
  }

  void _showDetail(Exercise exercise) => showModalBottomSheet<void>(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(expand: false, initialChildSize: .72, maxChildSize: .92, builder: (context, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
      if (exercise.imageAsset != null) ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset(exercise.imageAsset!, height: 190, fit: BoxFit.cover)),
      const SizedBox(height: 16), Text(exercise.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      Text(exercise.englishName), const SizedBox(height: 12), Text(exercise.purpose),
      const SizedBox(height: 16), const Text('진행 방법', style: TextStyle(fontWeight: FontWeight.w800)), ...exercise.instructions.map((e) => ListTile(dense: true, leading: const Icon(Icons.check_circle_outline), title: Text(e))),
      if (exercise.cues.isNotEmpty) ...[const Text('핵심 큐', style: TextStyle(fontWeight: FontWeight.w800)), Text(exercise.cues.join(' · '))],
      const SizedBox(height: 16), Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(14), child: Text(exercise.painGuide))),
      FilledButton.icon(onPressed: () { Navigator.pop(context); _add(exercise); }, icon: const Icon(Icons.add), label: const Text('운동에 추가')),
    ])),
  );
}
