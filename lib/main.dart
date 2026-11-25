import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/calendar_screen.dart';
import 'screens/settings_sheet.dart';
import 'screens/splash_screen.dart';
import 'screens/survival_screen.dart';
import 'screens/talk_screen.dart';
import 'screens/tasks_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.load();
  runApp(ClutchApp());
}

class ClutchApp extends StatelessWidget {
  ClutchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    // Rebuilds the whole app when the theme mode or accent changes.
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: C.dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: C.surface,
          systemNavigationBarIconBrightness: C.dark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'CLUTCH',
          scaffoldMessengerKey: state.messengerKey,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: SplashScreen(),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) => _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [SurvivalScreen(), CalendarScreen(), TasksScreen()],
      ),
      floatingActionButton: SizedBox(
        width: 68,
        height: 68,
        child: FloatingActionButton(
          backgroundColor: C.accent,
          foregroundColor: C.onAccent,
          shape: CircleBorder(),
          elevation: 6,
          onPressed: () => openTalk(context, autoListen: true),
          child: Icon(Icons.mic, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: C.surface,
        shape: CircularNotchedRectangle(),
        notchMargin: 8,
        height: 68,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _nav(0, Icons.bolt, 'Survive'),
            _nav(1, Icons.calendar_month, 'Calendar'),
            SizedBox(width: 56),
            _nav(2, Icons.checklist, 'Tasks'),
            _navButton(Icons.tune, 'Settings', false, () => openSettings(context)),
          ],
        ),
      ),
    );
  }

  Widget _nav(int i, IconData icon, String label) =>
      _navButton(icon, label, _tab == i, () => setState(() => _tab = i));

  Widget _navButton(IconData icon, String label, bool selected, VoidCallback onTap) {
    final color = selected ? C.accent : C.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color),
          SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
