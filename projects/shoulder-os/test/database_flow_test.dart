import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shoulder_os/core/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('complete workout survives reopen and appears in calendar and analytics', () async {
    final temp = await Directory.systemTemp.createTemp('shoulder_os_test_');
    final path = '${temp.path}${Platform.pathSeparator}flow.sqlite';
    final db = AppDatabase(factory: databaseFactoryFfi, overridePath: path);
    await db.initialize();

    final best = await db.bestExercises();
    expect(best.length, 6);
    final session = await db.startSession(type: 'rehab');
    await db.addExerciseToSession(session, best.first);
    final active = await db.loadActiveExercises(session);
    expect(active, hasLength(1));
    await db.updateSet(active.first.sets.first.copyWith(completed: true));
    await db.finishSession(session, painMax: 3, painLocation: '뒤');
    await db.close();

    final reopened = AppDatabase(factory: databaseFactoryFfi, overridePath: path);
    final events = await reopened.eventsForDate(DateTime.now());
    final analytics = await reopened.analytics();
    expect(events.any((event) => event['title']!.contains('재활')), isTrue);
    expect(analytics.workouts, 1);
    expect(analytics.sets, 1);
    expect(analytics.maxPain, 3);
    expect(await reopened.activeSessionId(), isNull);
    await reopened.close();
    await temp.delete(recursive: true);
  });

  test('routine, tennis, treatment, pain, and next-day records are persisted', () async {
    final temp = await Directory.systemTemp.createTemp('shoulder_os_test_');
    final path = '${temp.path}${Platform.pathSeparator}records.sqlite';
    final db = AppDatabase(factory: databaseFactoryFfi, overridePath: path);
    await db.initialize();
    final routines = await db.routines();
    expect(routines.map((e) => e.name), containsAll(['어깨 BEST 6', 'PC 3분', '차량 주차 후 3분', '집 재활 10분']));
    final customRoutine = await db.createRoutine('검증 루틴', '사용자', [(await db.bestExercises()).first.id]);
    expect(await db.routineExercises(customRoutine), hasLength(1));

    await db.savePain(level: 2, location: '뒤');
    await db.saveTennis(date: DateTime.now(), minutes: 60, intensity: 3, kind: '연습', served: true, pain: 2, note: '서브 연습');
    await db.saveTreatment(date: DateTime.now(), hospital: '테스트 병원', type: '물리치료', note: '회전근개');
    await db.saveNextDayResponse(1, '어제 재활');
    final events = await db.eventsForDate(DateTime.now());
    final tennisEvent = events.firstWhere((event) => event['title']!.contains('테니스'));
    expect(tennisEvent['duration_minutes'], '60');
    expect(tennisEvent['shoulder_pain'], '2');
    expect(tennisEvent['note'], '서브 연습');
    expect(events.any((event) => event['title']!.contains('물리치료')), isTrue);
    expect(events.any((event) => event['title']!.contains('통증')), isTrue);
    expect(await db.hasTodayNextDayResponse(), isTrue);

    final tennisId = int.parse(tennisEvent['id']!);
    final nextDay = DateTime.now().add(const Duration(days: 1));
    await db.updateTennis(id: tennisId, date: nextDay, minutes: 90, intensity: 4, kind: '게임', served: false, pain: 1, note: '게임으로 수정');
    expect((await db.eventsForDate(DateTime.now())).where((event) => event['kind'] == 'tennis'), isEmpty);
    final updatedEvent = (await db.eventsForDate(nextDay)).singleWhere((event) => event['kind'] == 'tennis');
    expect(updatedEvent['duration_minutes'], '90');
    expect(updatedEvent['session_kind'], '게임');
    expect(updatedEvent['note'], '게임으로 수정');
    await db.deleteTennis(tennisId);
    expect((await db.eventsForDate(nextDay)).where((event) => event['kind'] == 'tennis'), isEmpty);
    await db.close();
    await temp.delete(recursive: true);
  });
}
