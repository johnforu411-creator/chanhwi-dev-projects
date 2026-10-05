import 'package:flutter_test/flutter_test.dart';
import 'package:shoulder_os/core/models.dart';

void main() {
  test('rehab exercise decodes structured guidance', () {
    final exercise = Exercise.fromMap({
      'id': 'test', 'name': '외회전', 'english_name': 'External rotation',
      'category': '재활', 'primary_muscle': '회전근개', 'default_sets': 3,
      'default_reps': 10, 'default_duration_sec': 20, 'is_favorite': 0,
      'is_best': 1, 'best_priority': 2, 'rehab_phase': 1,
      'track_shoulder_pain': 1, 'purpose': '안정화',
      'instructions_json': '["팔꿈치를 고정한다"]',
      'cues_json': '["통증 없는 범위"]', 'mistakes_json': '[]',
      'pain_guide': '5 이상 중단',
    });
    expect(exercise.isRehab, isTrue);
    expect(exercise.isTimed, isTrue);
    expect(exercise.instructions, ['팔꿈치를 고정한다']);
  });

  test('workout set copy keeps unchanged fields', () {
    const set = WorkoutSetData(id: 1, setNumber: 1, weight: 20, reps: 10, durationSec: 0, completed: false);
    final changed = set.copyWith(weight: 22.5, completed: true);
    expect(changed.weight, 22.5);
    expect(changed.reps, 10);
    expect(changed.completed, isTrue);
  });
}
