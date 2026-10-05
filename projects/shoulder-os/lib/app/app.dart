import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/exercises/exercise_library_screen.dart';
import '../features/exercises/live_workout_screen.dart';
import '../features/exercises/rehab_session_screen.dart';
import '../features/routines/routines_screen.dart';
import '../features/today/today_screen.dart';

class ShoulderOsApp extends StatefulWidget {
  const ShoulderOsApp({super.key, required this.controller});
  final AppController controller;

  @override
  State<ShoulderOsApp> createState() => _ShoulderOsAppState();
}

class _ShoulderOsAppState extends State<ShoulderOsApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Shoulder OS',
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.system,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!widget.controller.ready && widget.controller.error == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (widget.controller.error != null) {
          return Scaffold(body: Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('앱을 시작하지 못했습니다.\n${widget.controller.error}', textAlign: TextAlign.center),
          )));
        }
        return AppShell(controller: widget.controller);
      },
    ),
    onGenerateRoute: (settings) {
      if (settings.name == '/workout' || settings.name == '/rehab' || settings.name == '/pain' || settings.name == '/calendar') {
        return MaterialPageRoute(settings: settings, builder: (_) => _WidgetActionScreen(controller: widget.controller, action: settings.name!));
      }
      return null;
    },
  );

  ThemeData _theme(Brightness brightness) {
    const seed = Color(0xff276b5d);
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'NanumGothic',
      scaffoldBackgroundColor: brightness == Brightness.light ? const Color(0xfff5f7f4) : const Color(0xff101412),
      cardTheme: CardThemeData(elevation: 0, color: scheme.surfaceContainerLow, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      inputDecorationTheme: InputDecorationTheme(filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
    );
  }
}

class _WidgetActionScreen extends StatefulWidget {
  const _WidgetActionScreen({required this.controller, required this.action});
  final AppController controller;
  final String action;
  @override
  State<_WidgetActionScreen> createState() => _WidgetActionScreenState();
}

class _WidgetActionScreenState extends State<_WidgetActionScreen> {
  bool handled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!handled) {
      handled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _handle());
    }
  }

  Future<void> _handle() async {
    while (!widget.controller.ready && widget.controller.error == null) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;
    if (widget.action == '/rehab') {
      final routines = await widget.controller.db.routines();
      final best = routines.where((r) => r.name.contains('BEST')).first;
      await widget.controller.startRoutine(best.id);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RehabSessionScreen(controller: widget.controller)));
    } else if (widget.action == '/pain') {
      var pain = 0.0;
      final value = await showDialog<int>(context: context, builder: (context) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: const Text('지금 통증 기록'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [Text('${pain.round()} / 10', style: Theme.of(context).textTheme.headlineMedium), Slider(value: pain, max: 10, divisions: 10, onChanged: (v) => setState(() => pain = v))]),
        actions: [FilledButton(onPressed: () => Navigator.pop(context, pain.round()), child: const Text('저장'))],
      )));
      if (value != null) await widget.controller.recordPain(level: value, location: '오른쪽 어깨', context: '위젯 빠른 기록');
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.action == '/calendar') return AppShell(controller: widget.controller, initialIndex: 3);
    if (widget.action == '/workout') return Scaffold(appBar: AppBar(title: const Text('운동 선택')), body: ExerciseLibraryScreen(controller: widget.controller));
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller, this.initialIndex = 0});
  final AppController controller;
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(controller: widget.controller, openWorkout: () => setState(() => index = 1)),
      ExerciseLibraryScreen(controller: widget.controller),
      RoutinesScreen(controller: widget.controller),
      CalendarScreen(controller: widget.controller),
      AnalyticsScreen(controller: widget.controller),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(['오늘', '운동', '루틴', '캘린더', '분석'][index]),
        actions: [
          if (widget.controller.activeSessionId != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: const Text('운동 중'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveWorkoutScreen(controller: widget.controller))),
              ),
            ),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: '오늘'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: '운동'),
          NavigationDestination(icon: Icon(Icons.playlist_play_outlined), selectedIcon: Icon(Icons.playlist_play), label: '루틴'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '캘린더'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: '분석'),
        ],
      ),
    );
  }
}
