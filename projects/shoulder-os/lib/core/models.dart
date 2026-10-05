import 'dart:convert';

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.englishName,
    required this.category,
    required this.primaryMuscle,
    required this.defaultSets,
    required this.defaultReps,
    required this.defaultDurationSec,
    required this.isFavorite,
    required this.isBest,
    required this.bestPriority,
    required this.rehabPhase,
    required this.trackShoulderPain,
    required this.imageAsset,
    required this.purpose,
    required this.instructions,
    required this.cues,
    required this.mistakes,
    required this.painGuide,
  });

  final String id;
  final String name;
  final String englishName;
  final String category;
  final String primaryMuscle;
  final int defaultSets;
  final int defaultReps;
  final int defaultDurationSec;
  final bool isFavorite;
  final bool isBest;
  final int? bestPriority;
  final int? rehabPhase;
  final bool trackShoulderPain;
  final String? imageAsset;
  final String purpose;
  final List<String> instructions;
  final List<String> cues;
  final List<String> mistakes;
  final String painGuide;

  bool get isTimed => defaultDurationSec > 0;
  bool get isRehab => category == '재활';

  factory Exercise.fromMap(Map<String, Object?> map) {
    List<String> decodeList(Object? value) {
      if (value == null || value.toString().isEmpty) return const [];
      return (jsonDecode(value.toString()) as List<dynamic>).cast<String>();
    }

    return Exercise(
      id: map['id']! as String,
      name: map['name']! as String,
      englishName: (map['english_name'] ?? '') as String,
      category: map['category']! as String,
      primaryMuscle: (map['primary_muscle'] ?? '') as String,
      defaultSets: (map['default_sets'] ?? 3) as int,
      defaultReps: (map['default_reps'] ?? 10) as int,
      defaultDurationSec: (map['default_duration_sec'] ?? 0) as int,
      isFavorite: (map['is_favorite'] ?? 0) == 1,
      isBest: (map['is_best'] ?? 0) == 1,
      bestPriority: map['best_priority'] as int?,
      rehabPhase: map['rehab_phase'] as int?,
      trackShoulderPain: (map['track_shoulder_pain'] ?? 0) == 1,
      imageAsset: map['image_asset'] as String?,
      purpose: (map['purpose'] ?? '') as String,
      instructions: decodeList(map['instructions_json']),
      cues: decodeList(map['cues_json']),
      mistakes: decodeList(map['mistakes_json']),
      painGuide: (map['pain_guide'] ?? '0~3 정상 진행 · 4 강도/ROM 감소 · 5 이상 중단') as String,
    );
  }
}

class WorkoutSetData {
  const WorkoutSetData({
    required this.id,
    required this.setNumber,
    required this.weight,
    required this.reps,
    required this.durationSec,
    required this.completed,
    this.rpe,
    this.rir,
    this.isWarmup = false,
    this.isFailure = false,
  });

  final int id;
  final int setNumber;
  final double weight;
  final int reps;
  final int durationSec;
  final bool completed;
  final double? rpe;
  final int? rir;
  final bool isWarmup;
  final bool isFailure;

  factory WorkoutSetData.fromMap(Map<String, Object?> map) => WorkoutSetData(
    id: map['id']! as int,
    setNumber: map['set_number']! as int,
    weight: (map['weight']! as num).toDouble(),
    reps: map['reps']! as int,
    durationSec: map['duration_sec']! as int,
    completed: map['completed'] == 1,
    rpe: (map['rpe'] as num?)?.toDouble(),
    rir: map['rir'] as int?,
    isWarmup: map['is_warmup'] == 1,
    isFailure: map['is_failure'] == 1,
  );

  WorkoutSetData copyWith({
    double? weight,
    int? reps,
    int? durationSec,
    bool? completed,
    double? rpe,
    int? rir,
    bool? isWarmup,
    bool? isFailure,
  }) => WorkoutSetData(
    id: id,
    setNumber: setNumber,
    weight: weight ?? this.weight,
    reps: reps ?? this.reps,
    durationSec: durationSec ?? this.durationSec,
    completed: completed ?? this.completed,
    rpe: rpe ?? this.rpe,
    rir: rir ?? this.rir,
    isWarmup: isWarmup ?? this.isWarmup,
    isFailure: isFailure ?? this.isFailure,
  );
}

class ActiveWorkoutExercise {
  const ActiveWorkoutExercise({
    required this.id,
    required this.exercise,
    required this.ordinal,
    required this.sets,
  });

  final int id;
  final Exercise exercise;
  final int ordinal;
  final List<WorkoutSetData> sets;

  ActiveWorkoutExercise copyWith({List<WorkoutSetData>? sets}) => ActiveWorkoutExercise(
    id: id,
    exercise: exercise,
    ordinal: ordinal,
    sets: sets ?? this.sets,
  );
}

class RoutineInfo {
  const RoutineInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.isFavorite,
    required this.exerciseCount,
    required this.estimatedMinutes,
  });

  final int id;
  final String name;
  final String category;
  final bool isFavorite;
  final int exerciseCount;
  final int estimatedMinutes;

  factory RoutineInfo.fromMap(Map<String, Object?> map) => RoutineInfo(
    id: map['id']! as int,
    name: map['name']! as String,
    category: map['category']! as String,
    isFavorite: map['is_favorite'] == 1,
    exerciseCount: (map['exercise_count']! as num).toInt(),
    estimatedMinutes: (map['estimated_minutes']! as num).round(),
  );
}

class CalendarDayData {
  const CalendarDayData({
    required this.date,
    required this.weightCount,
    required this.rehabCount,
    required this.tennisCount,
    required this.treatmentCount,
    required this.painCount,
  });

  final DateTime date;
  final int weightCount;
  final int rehabCount;
  final int tennisCount;
  final int treatmentCount;
  final int painCount;

  bool get hasEvents =>
      weightCount + rehabCount + tennisCount + treatmentCount + painCount > 0;
}

class AnalyticsData {
  const AnalyticsData({
    required this.workouts,
    required this.minutes,
    required this.sets,
    required this.volume,
    required this.averagePain,
    required this.maxPain,
    required this.rehabSessions,
    required this.tennisSessions,
    required this.nextDayAverage,
  });

  final int workouts;
  final int minutes;
  final int sets;
  final double volume;
  final double averagePain;
  final int maxPain;
  final int rehabSessions;
  final int tennisSessions;
  final double nextDayAverage;
}
