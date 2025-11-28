import 'package:flutter/material.dart';
import 'screens/shopping_list_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'services/database_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shopping List Pro',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      themeMode: ThemeMode.system,

      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  late ConnectivityService _connectivityService;
  late SyncService _syncService;
  late DatabaseService _databaseService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _connectivityService = ConnectivityService();
    _databaseService = DatabaseService();
    _syncService = SyncService(_connectivityService);

    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isLoggedIn = false;
      _isLoading = false;
    });
  }

  void _onLoginSuccess(String token, Map<String, dynamic> user) {
    ApiService.setAuthToken(token);
    setState(() {
      _isLoggedIn = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _isLoggedIn
        ? ShoppingListScreen(
            connectivityService: _connectivityService,
            syncService: _syncService,
            databaseService: _databaseService,
          )
        : LoginScreen(onLoginSuccess: _onLoginSuccess);
  }
}
