import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_database.dart';
import 'models.dart';

class AppController extends ChangeNotifier {
  AppController(this.db);

  final AppDatabase db;
  bool ready = false;
  Object? error;
  int? activeSessionId;
  String activeSessionType = 'weight';
  List<ActiveWorkoutExercise> activeExercises = const [];
  DateTime? restEndsAt;
  Timer? _restTicker;
  int revision = 0;

  int get restSecondsRemaining {
    final end = restEndsAt;
    if (end == null) return 0;
    final seconds = end.difference(DateTime.now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  Future<void> initialize() async {
    try {
      await db.initialize();
      activeSessionId = await db.activeSessionId();
      if (activeSessionId != null) {
        await reloadActive();
      }
      ready = true;
    } catch (exception) {
      error = exception;
    }
    notifyListeners();
  }

  Future<int> startWorkout({String type = 'weight'}) async {
    activeSessionId = await db.startSession(type: type);
    activeSessionType = type;
    await reloadActive();
    return activeSessionId!;
  }

  Future<void> reloadActive() async {
    final id = activeSessionId;
    if (id == null) {
      activeExercises = const [];
    } else {
      activeExercises = await db.loadActiveExercises(id);
    }
    notifyListeners();
  }

  Future<void> addExercise(Exercise exercise, {int? sets, int? reps, int? durationSec}) async {
    final id = activeSessionId ?? await startWorkout(type: exercise.isRehab ? 'rehab' : 'weight');
    await db.addExerciseToSession(id, exercise, sets: sets, reps: reps, durationSec: durationSec);
    await reloadActive();
  }

  Future<void> updateSet(int exerciseIndex, int setIndex, WorkoutSetData value) async {
    final exercise = activeExercises[exerciseIndex];
    final sets = [...exercise.sets];
    sets[setIndex] = value;
    final exercises = [...activeExercises];
    exercises[exerciseIndex] = exercise.copyWith(sets: sets);
    activeExercises = exercises;
    notifyListeners();
    await db.updateSet(value);
    if (value.completed) startRestTimer(value.durationSec > 0 ? 30 : 90);
  }

  Future<void> addSet(int workoutExerciseId) async {
    await db.addSet(workoutExerciseId);
    await reloadActive();
  }

  Future<void> deleteSet(int setId) async {
    await db.deleteSet(setId);
    await reloadActive();
  }

  void startRestTimer(int seconds) {
    restEndsAt = DateTime.now().add(Duration(seconds: seconds));
    _restTicker?.cancel();
    _restTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (restSecondsRemaining <= 0) {
        timer.cancel();
        restEndsAt = null;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void adjustRestTimer(int seconds) {
    restEndsAt = (restEndsAt ?? DateTime.now()).add(Duration(seconds: seconds));
    if (restSecondsRemaining <= 0) restEndsAt = null;
    notifyListeners();
  }

  void stopRestTimer() {
    _restTicker?.cancel();
    restEndsAt = null;
    notifyListeners();
  }

  Future<void> finishWorkout({int? painMax, String? painLocation, String note = ''}) async {
    final id = activeSessionId;
    if (id == null) return;
    await db.finishSession(id, painMax: painMax, painLocation: painLocation, note: note);
    activeSessionId = null;
    activeExercises = const [];
    stopRestTimer();
    revision++;
    notifyListeners();
  }

  Future<void> startRoutine(int routineId) async {
    final rows = await db.routineExercises(routineId);
    await startWorkout(type: rows.every((row) => row['category'] == '재활') ? 'rehab' : 'weight');
    for (final row in rows) {
      await addExercise(
        Exercise.fromMap(row),
        sets: row['routine_sets'] as int,
        reps: row['routine_reps'] as int,
        durationSec: row['routine_duration_sec'] as int,
      );
    }
    await reloadActive();
  }

  Future<void> recordPain({required int level, String? location, String context = '일상'}) async {
    await db.savePain(level: level, location: location, context: context);
    revision++;
    notifyListeners();
  }

  Future<void> refresh() async {
    revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _restTicker?.cancel();
    db.close();
    super.dispose();
  }
}

