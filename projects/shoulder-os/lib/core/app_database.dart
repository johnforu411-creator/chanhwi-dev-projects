import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class AppDatabase {
  AppDatabase({DatabaseFactory? factory, this.overridePath})
    : factory = factory ?? databaseFactory;

  final DatabaseFactory factory;
  final String? overridePath;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = overridePath ?? p.join(await getDatabasesPath(), 'shoulder_os_v2.sqlite');
    _database = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onOpen: _seed,
      ),
    );
    return _database!;
  }

  Future<void> initialize() async => database;

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        english_name TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL,
        primary_muscle TEXT NOT NULL DEFAULT '',
        default_sets INTEGER NOT NULL DEFAULT 3,
        default_reps INTEGER NOT NULL DEFAULT 10,
        default_duration_sec INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_best INTEGER NOT NULL DEFAULT 0,
        best_priority INTEGER,
        rehab_phase INTEGER,
        track_shoulder_pain INTEGER NOT NULL DEFAULT 0,
        image_asset TEXT,
        purpose TEXT NOT NULL DEFAULT '',
        instructions_json TEXT NOT NULL DEFAULT '[]',
        cues_json TEXT NOT NULL DEFAULT '[]',
        mistakes_json TEXT NOT NULL DEFAULT '[]',
        pain_guide TEXT NOT NULL DEFAULT '0~3 정상 진행 · 4 강도/ROM 감소 · 5 이상 중단',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        session_type TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        pain_max INTEGER,
        pain_location TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
        exercise_id TEXT NOT NULL REFERENCES exercises(id),
        ordinal INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_exercise_id INTEGER NOT NULL REFERENCES workout_exercises(id) ON DELETE CASCADE,
        set_number INTEGER NOT NULL,
        weight REAL NOT NULL DEFAULT 0,
        reps INTEGER NOT NULL DEFAULT 0,
        duration_sec INTEGER NOT NULL DEFAULT 0,
        completed INTEGER NOT NULL DEFAULT 0,
        rpe REAL,
        rir INTEGER,
        is_warmup INTEGER NOT NULL DEFAULT 0,
        is_failure INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE routine_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
        exercise_id TEXT NOT NULL REFERENCES exercises(id),
        ordinal INTEGER NOT NULL,
        sets INTEGER NOT NULL,
        reps INTEGER NOT NULL,
        duration_sec INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE pain_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recorded_at TEXT NOT NULL,
        context TEXT NOT NULL,
        pain_level INTEGER NOT NULL,
        location TEXT,
        session_id INTEGER REFERENCES workout_sessions(id) ON DELETE SET NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE daily_conditions (
        date TEXT PRIMARY KEY,
        pain_level INTEGER NOT NULL,
        condition TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE next_day_responses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        response_date TEXT NOT NULL UNIQUE,
        compared_to_date TEXT NOT NULL,
        response_value INTEGER NOT NULL,
        linked_summary TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE treatment_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        treatment_date TEXT NOT NULL,
        hospital_name TEXT NOT NULL DEFAULT '',
        treatment_type TEXT NOT NULL,
        body_part TEXT NOT NULL DEFAULT '오른쪽 어깨',
        note TEXT NOT NULL DEFAULT '',
        pain_before INTEGER,
        pain_day1 INTEGER,
        pain_day3 INTEGER,
        pain_day7 INTEGER,
        attachment_uri TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE tennis_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_date TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        intensity INTEGER NOT NULL,
        session_kind TEXT NOT NULL,
        served INTEGER NOT NULL DEFAULT 0,
        shoulder_pain INTEGER,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX workout_session_date_idx ON workout_sessions(started_at)');
    await db.execute('CREATE INDEX workout_set_exercise_idx ON workout_sets(workout_exercise_id)');
    await db.execute('CREATE INDEX pain_date_idx ON pain_records(recorded_at)');
  }

  Future<void> _seed(Database db) async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM exercises')) ?? 0;
    if (count > 0) return;
    final now = DateTime.now().toIso8601String();
    final exercises = <Map<String, Object?>>[
      _exercise('bench_press', '벤치프레스', 'Bench Press', '가슴', '대흉근', trackPain: true),
      _exercise('incline_press', '인클라인 프레스', 'Incline Press', '가슴', '대흉근 상부', trackPain: true),
      _exercise('push_up', '푸시업', 'Push-Up', '가슴', '대흉근', trackPain: true),
      _exercise('lat_pulldown', '랫풀다운', 'Lat Pulldown', '등', '광배근', trackPain: true),
      _exercise('seated_row', '시티드 로우', 'Seated Row', '등', '광배근·능형근', trackPain: true),
      _exercise('deadlift', '데드리프트', 'Deadlift', '등', '척추기립근·둔근'),
      _exercise('shoulder_press', '숄더프레스', 'Shoulder Press', '어깨', '삼각근', trackPain: true),
      _exercise('lateral_raise', '사이드 레터럴 레이즈', 'Lateral Raise', '어깨', '삼각근 측면', trackPain: true),
      _exercise('rear_delt_fly', '리어 델트 플라이', 'Rear Delt Fly', '어깨', '삼각근 후면', trackPain: true),
      _exercise('biceps_curl', '바이셉스 컬', 'Biceps Curl', '팔', '상완이두근'),
      _exercise('triceps_pushdown', '트라이셉스 푸시다운', 'Triceps Pushdown', '팔', '상완삼두근'),
      _exercise('squat', '스쿼트', 'Squat', '하체', '대퇴사두근·둔근'),
      _exercise('leg_press', '레그프레스', 'Leg Press', '하체', '대퇴사두근'),
      _exercise('romanian_deadlift', '루마니안 데드리프트', 'Romanian Deadlift', '하체', '햄스트링·둔근'),
      _exercise('plank', '플랭크', 'Plank', '코어', '복횡근', reps: 1, duration: 30),
      _rehab(
        id: 'posture_reset',
        name: '어깨 자세 리셋',
        english: 'Shoulder Posture Reset',
        muscle: '견갑 안정화 근육',
        priority: 1,
        sets: 1,
        duration: 30,
        image: 'assets/exercises/hands_on_thigh_posture_reset_atlas_v1.webp',
        purpose: '목과 어깨의 불필요한 긴장을 낮추고 편안한 중립 자세를 찾습니다.',
        instructions: ['어깨를 으쓱하지 않습니다.', '목을 길게 유지하고 팔꿈치는 몸 가까이에 둡니다.', '날개뼈를 세게 조이지 않고 20~30초 유지합니다.'],
        cues: ['가슴을 과하게 내밀지 않기', '어깨 힘 빼기', '운전 중 가능한 유일한 재활'],
        mistakes: ['견갑골을 강하게 조임', '허리를 과하게 젖힘', '어깨를 아래로 억지로 누름'],
      ),
      _rehab(
        id: 'external_rotation_isometric',
        name: '외회전 등척성',
        english: 'Isometric External Rotation',
        muscle: '극하근·소원근·회전근개',
        priority: 2,
        duration: 20,
        image: 'assets/exercises/external_rotation_isometric_wall_atlas_v1.webp',
        purpose: '낮은 강도로 외회전 회전근개를 다시 활성화합니다.',
        instructions: ['팔꿈치를 90도로 굽혀 몸통에 붙입니다.', '손등을 벽이나 반대손에 댑니다.', '팔은 움직이지 않고 최대 힘의 20~30%로 바깥쪽 힘을 줍니다.'],
        cues: ['팔꿈치 몸통 고정', '실제 움직임 없이', '호흡 유지'],
        mistakes: ['팔꿈치가 벌어짐', '몸통을 함께 돌림', '처음부터 최대 힘 사용'],
      ),
      _rehab(
        id: 'internal_rotation_isometric',
        name: '내회전 등척성',
        english: 'Isometric Internal Rotation',
        muscle: '견갑하근·회전근개',
        priority: 3,
        duration: 20,
        image: 'assets/exercises/internal_rotation_isometric_atlas_v1.webp',
        purpose: '통증을 자극하지 않는 범위에서 내회전 회전근개에 부하를 적응시킵니다.',
        instructions: ['팔꿈치를 몸통에 붙입니다.', '손바닥을 벽이나 반대손에 댑니다.', '손을 배 쪽으로 돌리는 힘만 20~30%로 줍니다.'],
        cues: ['관절 움직임 없이', '손목 힘이 아닌 어깨 힘', '통증 0~3 범위'],
        mistakes: ['몸통 회전', '팔꿈치 벌어짐', '강한 통증을 참고 지속'],
      ),
      _rehab(
        id: 'short_lever_scaption',
        name: '짧은 레버 스캡션',
        english: 'Short-Lever Scaption',
        muscle: '극상근·삼각근·회전근개',
        priority: 4,
        sets: 2,
        reps: 10,
        image: 'assets/exercises/character_master_v1.webp',
        purpose: '통증이 큰 70~90도 구간을 피하며 능동 거상 조절을 회복합니다.',
        instructions: ['팔을 정면과 옆면 사이 약 30도 방향에 둡니다.', '엄지는 위로, 팔꿈치는 약간 굽힙니다.', '초기에는 0~45~60도까지만 천천히 올립니다.'],
        cues: ['어깨 으쓱 금지', '통증 구간 전에서 멈추기', '천천히 내리기'],
        mistakes: ['정확히 옆으로 들기', '처음부터 90도 반복', '반동 사용'],
      ),
      _rehab(
        id: 'serratus_reach',
        name: 'Serratus Reach',
        english: 'Serratus Reach',
        muscle: '전거근·견갑 안정화 근육',
        priority: 5,
        sets: 2,
        reps: 12,
        image: 'assets/exercises/scapular_forward_reach_atlas_v1.webp',
        purpose: '견갑골이 흉곽을 따라 부드럽게 움직이도록 전거근 조절을 연습합니다.',
        instructions: ['팔을 30~45도 앞으로 둡니다.', '팔꿈치를 거의 편 채 손을 2~3cm 앞으로 내밉니다.', '견갑골이 흉곽을 따라 움직인 뒤 천천히 복귀합니다.'],
        cues: ['어깨 으쓱 금지', '작은 범위', '팔꿈치 반복 굽힘 금지'],
        mistakes: ['허리를 굽힘', '어깨를 귀 쪽으로 올림', '날개뼈를 과하게 조임'],
      ),
      _rehab(
        id: 'low_row_isometric',
        name: 'Low Row Isometric',
        english: 'Low Row Isometric',
        muscle: '중·하부 승모근·능형근',
        priority: 6,
        duration: 15,
        image: 'assets/exercises/band_row_hold_atlas_v1.webp',
        purpose: '어깨와 견갑골이 안정된 위치에서 낮은 부하를 받아들이게 합니다.',
        instructions: ['팔꿈치를 몸통 가까이에 둡니다.', '팔꿈치를 뒤로 당기려는 힘을 약하게 줍니다.', '날개뼈를 강하게 조이지 않고 10~15초 유지합니다.'],
        cues: ['어깨 으쓱 금지', '가슴 과도하게 내밀지 않기', '약한 힘'],
        mistakes: ['견갑골을 최대한 조임', '허리 과신전', '팔꿈치가 벌어짐'],
      ),
    ];

    final batch = db.batch();
    for (final exercise in exercises) {
      batch.insert('exercises', {...exercise, 'created_at': now});
    }
    await batch.commit(noResult: true);
    await _seedRoutines(db, now);
    await db.insert('app_settings', {'key': 'pain_reduce_threshold', 'value': '4'});
    await db.insert('app_settings', {'key': 'pain_stop_threshold', 'value': '5'});
  }

  Map<String, Object?> _exercise(
    String id,
    String name,
    String english,
    String category,
    String muscle, {
    int sets = 3,
    int reps = 10,
    int duration = 0,
    bool trackPain = false,
  }) => {
    'id': id,
    'name': name,
    'english_name': english,
    'category': category,
    'primary_muscle': muscle,
    'default_sets': sets,
    'default_reps': reps,
    'default_duration_sec': duration,
    'is_favorite': 0,
    'is_best': 0,
    'track_shoulder_pain': trackPain ? 1 : 0,
  };

  Map<String, Object?> _rehab({
    required String id,
    required String name,
    required String english,
    required String muscle,
    required int priority,
    int sets = 3,
    int reps = 1,
    int duration = 0,
    required String image,
    required String purpose,
    required List<String> instructions,
    required List<String> cues,
    required List<String> mistakes,
  }) => {
    'id': id,
    'name': name,
    'english_name': english,
    'category': '재활',
    'primary_muscle': muscle,
    'default_sets': sets,
    'default_reps': reps,
    'default_duration_sec': duration,
    'is_favorite': 1,
    'is_best': 1,
    'best_priority': priority,
    'rehab_phase': 1,
    'track_shoulder_pain': 1,
    'image_asset': image,
    'purpose': purpose,
    'instructions_json': jsonEncode(instructions),
    'cues_json': jsonEncode(cues),
    'mistakes_json': jsonEncode(mistakes),
  };

  Future<void> _seedRoutines(Database db, String now) async {
    Future<void> addRoutine(String name, String category, List<String> ids) async {
      final routineId = await db.insert('routines', {
        'name': name,
        'category': category,
        'is_favorite': 1,
        'created_at': now,
      });
      for (var i = 0; i < ids.length; i++) {
        final exercise = await db.query('exercises', where: 'id = ?', whereArgs: [ids[i]], limit: 1);
        if (exercise.isEmpty) continue;
        await db.insert('routine_exercises', {
          'routine_id': routineId,
          'exercise_id': ids[i],
          'ordinal': i,
          'sets': exercise.first['default_sets'],
          'reps': exercise.first['default_reps'],
          'duration_sec': exercise.first['default_duration_sec'],
        });
      }
    }

    const best = [
      'posture_reset',
      'external_rotation_isometric',
      'internal_rotation_isometric',
      'short_lever_scaption',
      'serratus_reach',
      'low_row_isometric',
    ];
    await addRoutine('어깨 BEST 6', '재활', best);
    await addRoutine('PC 3분', 'Quick', ['posture_reset', 'serratus_reach', 'low_row_isometric']);
    await addRoutine('차량 주차 후 3분', 'Quick', [
      'external_rotation_isometric',
      'internal_rotation_isometric',
      'low_row_isometric',
    ]);
    await addRoutine('집 재활 10분', '재활', best);
  }

  Future<List<Exercise>> exercises({String? category, String query = ''}) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (category != null && category.isNotEmpty && category != '전체') {
      if (category == '최근') {
        // Recent ordering is handled below without narrowing the library.
      } else if (category == '즐겨찾기') {
        clauses.add('is_favorite = 1');
      } else if (category == 'BEST 재활') {
        clauses.add('is_best = 1');
      } else {
        clauses.add('category = ?');
        args.add(category);
      }
    }
    if (query.trim().isNotEmpty) {
      clauses.add('(name LIKE ? OR english_name LIKE ? OR primary_muscle LIKE ?)');
      final value = '%${query.trim()}%';
      args.addAll([value, value, value]);
    }
    final rows = await db.query(
      'exercises',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: category == '최근'
          ? '''COALESCE((SELECT MAX(ws.created_at) FROM workout_sets ws
                JOIN workout_exercises we ON we.id = ws.workout_exercise_id
                WHERE we.exercise_id = exercises.id AND ws.completed = 1), '') DESC, name'''
          : 'is_best DESC, best_priority, is_favorite DESC, name',
    );
    return rows.map(Exercise.fromMap).toList();
  }

  Future<List<Exercise>> bestExercises() async => exercises(category: 'BEST 재활');

  Future<void> toggleFavorite(String id, bool value) async {
    final db = await database;
    await db.update('exercises', {'is_favorite': value ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> startSession({String type = 'weight'}) async {
    final db = await database;
    final active = await db.query(
      'workout_sessions',
      columns: ['id'],
      where: 'ended_at IS NULL',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (active.isNotEmpty) return active.first['id']! as int;
    final now = DateTime.now().toIso8601String();
    return db.insert('workout_sessions', {
      'started_at': now,
      'session_type': type,
      'created_at': now,
    });
  }

  Future<int?> activeSessionId() async {
    final db = await database;
    final rows = await db.query(
      'workout_sessions',
      columns: ['id'],
      where: 'ended_at IS NULL',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id']! as int;
  }

  Future<List<ActiveWorkoutExercise>> loadActiveExercises(int sessionId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT we.id AS workout_exercise_id, we.ordinal, e.*
      FROM workout_exercises we
      JOIN exercises e ON e.id = we.exercise_id
      WHERE we.session_id = ?
      ORDER BY we.ordinal
    ''', [sessionId]);
    final result = <ActiveWorkoutExercise>[];
    for (final row in rows) {
      final setRows = await db.query(
        'workout_sets',
        where: 'workout_exercise_id = ?',
        whereArgs: [row['workout_exercise_id']],
        orderBy: 'set_number',
      );
      result.add(ActiveWorkoutExercise(
        id: row['workout_exercise_id']! as int,
        exercise: Exercise.fromMap(row),
        ordinal: row['ordinal']! as int,
        sets: setRows.map(WorkoutSetData.fromMap).toList(),
      ));
    }
    return result;
  }

  Future<int> addExerciseToSession(int sessionId, Exercise exercise, {int? sets, int? reps, int? durationSec}) async {
    final db = await database;
    final existing = await db.query(
      'workout_exercises',
      columns: ['id'],
      where: 'session_id = ? AND exercise_id = ?',
      whereArgs: [sessionId, exercise.id],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id']! as int;
    final maxOrdinal = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COALESCE(MAX(ordinal), -1) FROM workout_exercises WHERE session_id = ?',
      [sessionId],
    )) ?? -1;
    final workoutExerciseId = await db.insert('workout_exercises', {
      'session_id': sessionId,
      'exercise_id': exercise.id,
      'ordinal': maxOrdinal + 1,
    });
    final last = await lastCompletedSets(exercise.id);
    final count = sets ?? exercise.defaultSets;
    final now = DateTime.now().toIso8601String();
    for (var i = 0; i < count; i++) {
      final previous = i < last.length ? last[i] : (last.isNotEmpty ? last.last : null);
      await db.insert('workout_sets', {
        'workout_exercise_id': workoutExerciseId,
        'set_number': i + 1,
        'weight': previous?.weight ?? 0,
        'reps': reps ?? previous?.reps ?? exercise.defaultReps,
        'duration_sec': durationSec ?? previous?.durationSec ?? exercise.defaultDurationSec,
        'completed': 0,
        'created_at': now,
      });
    }
    return workoutExerciseId;
  }

  Future<List<WorkoutSetData>> lastCompletedSets(String exerciseId) async {
    final db = await database;
    final sessions = await db.rawQuery('''
      SELECT we.id
      FROM workout_exercises we
      JOIN workout_sessions s ON s.id = we.session_id
      WHERE we.exercise_id = ? AND s.ended_at IS NOT NULL
      ORDER BY s.started_at DESC
      LIMIT 1
    ''', [exerciseId]);
    if (sessions.isEmpty) return const [];
    final rows = await db.query(
      'workout_sets',
      where: 'workout_exercise_id = ? AND completed = 1',
      whereArgs: [sessions.first['id']],
      orderBy: 'set_number',
    );
    return rows.map(WorkoutSetData.fromMap).toList();
  }

  Future<void> updateSet(WorkoutSetData set) async {
    final db = await database;
    await db.update('workout_sets', {
      'weight': set.weight,
      'reps': set.reps,
      'duration_sec': set.durationSec,
      'completed': set.completed ? 1 : 0,
      'rpe': set.rpe,
      'rir': set.rir,
      'is_warmup': set.isWarmup ? 1 : 0,
      'is_failure': set.isFailure ? 1 : 0,
    }, where: 'id = ?', whereArgs: [set.id]);
  }

  Future<void> addSet(int workoutExerciseId) async {
    final db = await database;
    final rows = await db.query(
      'workout_sets',
      where: 'workout_exercise_id = ?',
      whereArgs: [workoutExerciseId],
      orderBy: 'set_number DESC',
      limit: 1,
    );
    final last = rows.isEmpty ? null : WorkoutSetData.fromMap(rows.first);
    await db.insert('workout_sets', {
      'workout_exercise_id': workoutExerciseId,
      'set_number': (last?.setNumber ?? 0) + 1,
      'weight': last?.weight ?? 0,
      'reps': last?.reps ?? 10,
      'duration_sec': last?.durationSec ?? 0,
      'completed': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteSet(int id) async {
    final db = await database;
    await db.delete('workout_sets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> finishSession(int sessionId, {int? painMax, String? painLocation, String note = ''}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update('workout_sessions', {
      'ended_at': now,
      'pain_max': painMax,
      'pain_location': painLocation,
      'note': note,
    }, where: 'id = ?', whereArgs: [sessionId]);
    if (painMax != null) {
      await db.insert('pain_records', {
        'recorded_at': now,
        'context': '운동 중 최대',
        'pain_level': painMax,
        'location': painLocation,
        'session_id': sessionId,
      });
    }
  }

  Future<void> savePain({required int level, String? location, String context = '일상', String note = ''}) async {
    final db = await database;
    final now = DateTime.now();
    await db.insert('pain_records', {
      'recorded_at': now.toIso8601String(),
      'context': context,
      'pain_level': level,
      'location': location,
      'note': note,
    });
    await db.insert('daily_conditions', {
      'date': dayKey(now),
      'pain_level': level,
      'condition': level <= 2 ? '좋음' : level <= 4 ? '보통' : '주의',
      'updated_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> todayCondition() async {
    final db = await database;
    final rows = await db.query('daily_conditions', where: 'date = ?', whereArgs: [dayKey(DateTime.now())], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<String?> yesterdayWorkoutSummary() async {
    final db = await database;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final start = DateTime(yesterday.year, yesterday.month, yesterday.day).toIso8601String();
    final end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59).toIso8601String();
    final rows = await db.rawQuery('''
      SELECT DISTINCT e.name
      FROM workout_sessions s
      JOIN workout_exercises we ON we.session_id = s.id
      JOIN exercises e ON e.id = we.exercise_id
      WHERE s.started_at BETWEEN ? AND ? AND s.ended_at IS NOT NULL
      ORDER BY we.ordinal
    ''', [start, end]);
    final tennis = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM tennis_sessions WHERE session_date = ?',
      [dayKey(yesterday)],
    )) ?? 0;
    final names = rows.map((e) => e['name'] as String).toList();
    if (tennis > 0) names.add('테니스');
    return names.isEmpty ? null : names.join(' · ');
  }

  Future<bool> hasTodayNextDayResponse() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM next_day_responses WHERE response_date = ?',
      [dayKey(DateTime.now())],
    )) ?? 0;
    return count > 0;
  }

  Future<void> saveNextDayResponse(int value, String summary) async {
    final db = await database;
    final now = DateTime.now();
    await db.insert('next_day_responses', {
      'response_date': dayKey(now),
      'compared_to_date': dayKey(now.subtract(const Duration(days: 1))),
      'response_value': value,
      'linked_summary': summary,
      'created_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RoutineInfo>> routines() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT r.*, COUNT(re.id) AS exercise_count,
             COALESCE(SUM(CASE WHEN re.duration_sec > 0
               THEN re.sets * re.duration_sec ELSE re.sets * 50 END) / 60, 0) AS estimated_minutes
      FROM routines r
      LEFT JOIN routine_exercises re ON re.routine_id = r.id
      GROUP BY r.id
      ORDER BY r.is_favorite DESC, r.id
    ''');
    return rows.map(RoutineInfo.fromMap).toList();
  }

  Future<int> createRoutine(String name, String category, List<String> exerciseIds) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('routines', {
        'name': name,
        'category': category,
        'is_favorite': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (var i = 0; i < exerciseIds.length; i++) {
        final rows = await txn.query('exercises', where: 'id = ?', whereArgs: [exerciseIds[i]], limit: 1);
        if (rows.isEmpty) continue;
        await txn.insert('routine_exercises', {
          'routine_id': id,
          'exercise_id': exerciseIds[i],
          'ordinal': i,
          'sets': rows.first['default_sets'],
          'reps': rows.first['default_reps'],
          'duration_sec': rows.first['default_duration_sec'],
        });
      }
      return id;
    });
  }

  Future<int> duplicateRoutine(int routineId) async {
    final db = await database;
    final source = await db.query('routines', where: 'id = ?', whereArgs: [routineId], limit: 1);
    if (source.isEmpty) throw StateError('Routine not found');
    final exercises = await db.query('routine_exercises', where: 'routine_id = ?', whereArgs: [routineId], orderBy: 'ordinal');
    return db.transaction((txn) async {
      final id = await txn.insert('routines', {
        'name': '${source.first['name']} 복사본',
        'category': source.first['category'],
        'is_favorite': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final item in exercises) {
        await txn.insert('routine_exercises', {
          'routine_id': id,
          'exercise_id': item['exercise_id'],
          'ordinal': item['ordinal'],
          'sets': item['sets'],
          'reps': item['reps'],
          'duration_sec': item['duration_sec'],
        });
      }
      return id;
    });
  }

  Future<List<Map<String, Object?>>> routineExercises(int routineId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT e.*,
             re.sets AS routine_sets,
             re.reps AS routine_reps,
             re.duration_sec AS routine_duration_sec,
             re.ordinal AS routine_ordinal
      FROM routine_exercises re
      JOIN exercises e ON e.id = re.exercise_id
      WHERE re.routine_id = ?
      ORDER BY re.ordinal
    ''', [routineId]);
  }

  Future<List<CalendarDayData>> calendarMonth(DateTime month) async {
    final db = await database;
    final first = DateTime(month.year, month.month, 1);
    final next = DateTime(month.year, month.month + 1, 1);
    final sessions = await db.rawQuery('''
      SELECT substr(started_at, 1, 10) AS day, session_type, COUNT(*) AS count
      FROM workout_sessions
      WHERE started_at >= ? AND started_at < ? AND ended_at IS NOT NULL
      GROUP BY day, session_type
    ''', [first.toIso8601String(), next.toIso8601String()]);
    final tennis = await db.rawQuery('''
      SELECT session_date AS day, COUNT(*) AS count FROM tennis_sessions
      WHERE session_date >= ? AND session_date < ? GROUP BY day
    ''', [dayKey(first), dayKey(next)]);
    final treatments = await db.rawQuery('''
      SELECT treatment_date AS day, COUNT(*) AS count FROM treatment_records
      WHERE treatment_date >= ? AND treatment_date < ? GROUP BY day
    ''', [dayKey(first), dayKey(next)]);
    final pain = await db.rawQuery('''
      SELECT substr(recorded_at, 1, 10) AS day, COUNT(*) AS count FROM pain_records
      WHERE recorded_at >= ? AND recorded_at < ? GROUP BY day
    ''', [first.toIso8601String(), next.toIso8601String()]);
    final result = <String, List<int>>{};
    void ensure(String key) => result.putIfAbsent(key, () => [0, 0, 0, 0, 0]);
    for (final row in sessions) {
      final key = row['day']! as String;
      ensure(key);
      final type = row['session_type'] as String;
      result[key]![type == 'rehab' ? 1 : 0] = row['count']! as int;
    }
    for (final row in tennis) {
      final key = row['day']! as String;
      ensure(key);
      result[key]![2] = row['count']! as int;
    }
    for (final row in treatments) {
      final key = row['day']! as String;
      ensure(key);
      result[key]![3] = row['count']! as int;
    }
    for (final row in pain) {
      final key = row['day']! as String;
      ensure(key);
      result[key]![4] = row['count']! as int;
    }
    return result.entries.map((entry) {
      final date = DateTime.parse(entry.key);
      return CalendarDayData(
        date: date,
        weightCount: entry.value[0],
        rehabCount: entry.value[1],
        tennisCount: entry.value[2],
        treatmentCount: entry.value[3],
        painCount: entry.value[4],
      );
    }).toList();
  }

  Future<List<Map<String, String>>> eventsForDate(DateTime date) async {
    final db = await database;
    final key = dayKey(date);
    final result = <Map<String, String>>[];
    final sessions = await db.rawQuery('''
      SELECT s.id, s.session_type, s.started_at, s.ended_at, s.pain_max,
             GROUP_CONCAT(DISTINCT e.name) AS names,
             SUM(CASE WHEN ws.completed = 1 THEN 1 ELSE 0 END) AS set_count,
             SUM(CASE WHEN ws.completed = 1 THEN ws.weight * ws.reps ELSE 0 END) AS volume
      FROM workout_sessions s
      LEFT JOIN workout_exercises we ON we.session_id = s.id
      LEFT JOIN exercises e ON e.id = we.exercise_id
      LEFT JOIN workout_sets ws ON ws.workout_exercise_id = we.id
      WHERE substr(s.started_at, 1, 10) = ? AND s.ended_at IS NOT NULL
      GROUP BY s.id ORDER BY s.started_at
    ''', [key]);
    for (final row in sessions) {
      final type = row['session_type'] == 'rehab' ? '🦴 재활' : '🏋 웨이트';
      final painText = row['pain_max'] == null ? '' : ' · 통증 ${row['pain_max']}';
      result.add({
        'title': type,
        'detail': '${row['names'] ?? '운동'} · ${row['set_count'] ?? 0}세트$painText',
      });
    }
    final tennis = await db.query('tennis_sessions', where: 'session_date = ?', whereArgs: [key]);
    for (final row in tennis) {
      final pain = row['shoulder_pain'] == null ? '' : ' · 어깨 ${row['shoulder_pain']}/10';
      result.add({
        'kind': 'tennis',
        'id': '${row['id']}',
        'title': '🎾 테니스',
        'detail': '${row['duration_minutes']}분 · 강도 ${row['intensity']}/5 · ${row['session_kind']}${row['served'] == 1 ? ' · 서브' : ''}$pain${(row['note'] as String).isEmpty ? '' : ' · ${row['note']}'}',
        'session_date': row['session_date'].toString(),
        'duration_minutes': row['duration_minutes'].toString(),
        'intensity': row['intensity'].toString(),
        'session_kind': row['session_kind'].toString(),
        'served': row['served'].toString(),
        'shoulder_pain': row['shoulder_pain']?.toString() ?? '',
        'note': row['note']?.toString() ?? '',
      });
    }
    final treatments = await db.query('treatment_records', where: 'treatment_date = ?', whereArgs: [key]);
    for (final row in treatments) {
      result.add({'title': '🏥 ${row['treatment_type']}', 'detail': '${row['hospital_name']}${(row['note'] as String).isEmpty ? '' : ' · ${row['note']}'}'});
    }
    final pain = await db.query('pain_records', where: 'substr(recorded_at, 1, 10) = ?', whereArgs: [key], orderBy: 'recorded_at');
    for (final row in pain) {
      result.add({'title': '😣 통증 ${row['pain_level']}/10', 'detail': '${row['context']}${row['location'] == null ? '' : ' · ${row['location']}'}'});
    }
    return result;
  }

  Future<void> saveTreatment({
    required DateTime date,
    required String hospital,
    required String type,
    required String note,
    int? painBefore,
  }) async {
    final db = await database;
    await db.insert('treatment_records', {
      'treatment_date': dayKey(date),
      'hospital_name': hospital,
      'treatment_type': type,
      'note': note,
      'pain_before': painBefore,
    });
  }

  Future<void> saveTennis({
    required DateTime date,
    required int minutes,
    required int intensity,
    required String kind,
    required bool served,
    int? pain,
    String note = '',
  }) async {
    final db = await database;
    await db.insert('tennis_sessions', {
      'session_date': dayKey(date),
      'duration_minutes': minutes,
      'intensity': intensity,
      'session_kind': kind,
      'served': served ? 1 : 0,
      'shoulder_pain': pain,
      'note': note,
    });
  }

  Future<void> updateTennis({
    required int id,
    required DateTime date,
    required int minutes,
    required int intensity,
    required String kind,
    required bool served,
    int? pain,
    String note = '',
  }) async {
    final db = await database;
    await db.update('tennis_sessions', {
      'session_date': dayKey(date),
      'duration_minutes': minutes,
      'intensity': intensity,
      'session_kind': kind,
      'served': served ? 1 : 0,
      'shoulder_pain': pain,
      'note': note,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTennis(int id) async {
    final db = await database;
    await db.delete('tennis_sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<AnalyticsData> analytics({int days = 28}) async {
    final db = await database;
    final from = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final sessionRows = await db.rawQuery('''
      SELECT COUNT(DISTINCT s.id) AS workouts,
             COALESCE(SUM(CASE WHEN s.ended_at IS NOT NULL
               THEN (julianday(s.ended_at) - julianday(s.started_at)) * 1440 ELSE 0 END), 0) AS minutes,
             COALESCE(SUM(CASE WHEN ws.completed = 1 THEN 1 ELSE 0 END), 0) AS sets,
             COALESCE(SUM(CASE WHEN ws.completed = 1 THEN ws.weight * ws.reps ELSE 0 END), 0) AS volume,
             COUNT(DISTINCT CASE WHEN s.session_type = 'rehab' THEN s.id END) AS rehab
      FROM workout_sessions s
      LEFT JOIN workout_exercises we ON we.session_id = s.id
      LEFT JOIN workout_sets ws ON ws.workout_exercise_id = we.id
      WHERE s.started_at >= ? AND s.ended_at IS NOT NULL
    ''', [from]);
    final painRows = await db.rawQuery('''
      SELECT COALESCE(AVG(pain_level), 0) AS average_pain,
             COALESCE(MAX(pain_level), 0) AS max_pain
      FROM pain_records WHERE recorded_at >= ?
    ''', [from]);
    final tennisCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM tennis_sessions WHERE session_date >= ?',
      [from.substring(0, 10)],
    )) ?? 0;
    final responseRows = await db.rawQuery('''
      SELECT COALESCE(AVG(response_value), 0) AS average_response
      FROM next_day_responses WHERE response_date >= ?
    ''', [from.substring(0, 10)]);
    final s = sessionRows.first;
    final pain = painRows.first;
    return AnalyticsData(
      workouts: (s['workouts'] as num).toInt(),
      minutes: (s['minutes'] as num).round(),
      sets: (s['sets'] as num).toInt(),
      volume: (s['volume'] as num).toDouble(),
      averagePain: (pain['average_pain'] as num).toDouble(),
      maxPain: (pain['max_pain'] as num).toInt(),
      rehabSessions: (s['rehab'] as num).toInt(),
      tennisSessions: tennisCount,
      nextDayAverage: (responseRows.first['average_response'] as num).toDouble(),
    );
  }

  Future<Map<String, Object?>?> lastExerciseRecord(String exerciseId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.started_at, ws.weight, ws.reps, ws.duration_sec
      FROM workout_sets ws
      JOIN workout_exercises we ON we.id = ws.workout_exercise_id
      JOIN workout_sessions s ON s.id = we.session_id
      WHERE we.exercise_id = ? AND ws.completed = 1 AND s.ended_at IS NOT NULL
      ORDER BY s.started_at DESC, ws.set_number
      LIMIT 1
    ''', [exerciseId]);
    return rows.isEmpty ? null : rows.first;
  }
}
