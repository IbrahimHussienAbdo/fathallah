import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    if (dart.library.io) 'package:sqflite/sqflite.dart';
import 'presentation/providers/app_provider.dart';
import 'presentation/screens/upload_screen.dart';
import 'presentation/screens/analytics_screen.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/theme/app_theme.dart';

/// App entry point.
/// On web, sets the sqflite factory to databaseFactoryFfiWeb before
/// any database call. Mobile needs no factory override.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(
    /// Provide [AppProvider] at the root so every screen can access state.
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const FathallahAnalytics(),
    ),
  );
}

class FathallahAnalytics extends StatelessWidget {
  const FathallahAnalytics({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fathallah Analytics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}

/// Root scaffold with a bottom [NavigationBar].
///
/// Uses [IndexedStack] so each screen retains its scroll position
/// and state when the user switches tabs.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  /// Fixed list of screens — order matches the navigation bar destinations.
  static const _screens = [
    UploadScreen(),
    AnalyticsScreen(),
    SearchScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

/// Custom bottom navigation bar with branded styling.
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppTheme.primary.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.upload_file_outlined),
            selectedIcon: Icon(Icons.upload_file, color: AppTheme.primary),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppTheme.primary),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: AppTheme.primary),
            label: 'Search',
          ),
        ],
      ),
    );
  }
}
