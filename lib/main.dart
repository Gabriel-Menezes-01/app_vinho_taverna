import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:io' show exit, Platform;
import 'services/database_service.dart';
import 'services/wine_service.dart';
import 'services/user_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar sqflite no Windows
  if (Platform.isWindows || Platform.isLinux) {
    try {
      await DatabaseService.initializeFFI();
      debugPrint('✓ SQLite FFI inicializado para Windows/Linux');
    } catch (e) {
      debugPrint('⚠️ Erro ao inicializar SQLite FFI: $e');
    }
  }

  // Inicializar Firebase com configurações corretas
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
    debugPrint('✓ Firebase inicializado com sucesso!');
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      // Firebase já inicializado
      firebaseInitialized = true;
      debugPrint('✓ Firebase já estava inicializado');
    } else {
      debugPrint('⚠️ Firebase não configurado (modo offline): $e');
      // Continuar sem Firebase - app funcionará offline
    }
  }

  // Inicializar serviços
  try {
    final dbService = DatabaseService();
    await dbService.database; // Garantir que o DB está inicializado
    debugPrint('✓ Database inicializado');
    
    // Criar SyncService primeiro
    final syncService = SyncService(dbService, firebaseEnabled: firebaseInitialized);
    
    // Passar o status do Firebase E o SyncService para os serviços
    final wineService = WineService(dbService, firebaseEnabled: firebaseInitialized, syncService: syncService);
    final userService = UserService(dbService, firebaseEnabled: firebaseInitialized);
    final authService = AuthService(dbService, firebaseEnabled: firebaseInitialized);
    
    debugPrint('✓ Serviços inicializados (Firebase: $firebaseInitialized)');
    
    runApp(MyApp(
      databaseService: dbService,
      wineService: wineService,
      userService: userService,
      authService: authService,
      syncService: syncService,
    ));
  } catch (e, stackTrace) {
    debugPrint('❌ Erro ao inicializar app: $e');
    debugPrint('Stack trace: $stackTrace');
    runApp(const ErrorApp());
  }
}

class MyApp extends StatelessWidget {
  final DatabaseService databaseService;
  final WineService wineService;
  final UserService userService;
  final AuthService authService;
  final SyncService syncService;

  const MyApp({
    super.key,
    required this.databaseService,
    required this.wineService,
    required this.userService,
    required this.authService,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cartas de Vinhos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF722F37), // Cor de vinho
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      home: FutureBuilder<bool>(
        future: authService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Verificando usuário...'),
                  ],
                ),
              ),
            );
          }

          // Se erro ou usuário não autenticado, ir para login
          if (snapshot.hasError || snapshot.data != true) {
            debugPrint('❌ Erro na autenticação ou usuário não logado: ${snapshot.error}');
            return LoginScreen(
              userService: userService,
              wineService: wineService,
              syncService: syncService,
              databaseService: databaseService,
            );
          }

          // Usuário autenticado e verificado
          debugPrint('✅ Usuário autenticado em ${Platform.operatingSystem}');
          return HomeScreen(
            wineService: wineService,
            userService: userService,
            syncService: syncService,
            databaseService: databaseService,
            );
          }

          return LoginScreen(
            userService: userService,
            wineService: wineService,
            syncService: syncService,
            databaseService: databaseService,
          );
        },
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Erro ao inicializar o app'),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Reinicie o aplicativo. Se o problema persistir, desinstale e reinstale.',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => exit(0),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
