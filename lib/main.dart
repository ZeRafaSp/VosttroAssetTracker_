// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:vosttro_asset_tracker/screens/login_screen.dart';
import 'package:vosttro_asset_tracker/screens/home_screen.dart';
import 'package:vosttro_asset_tracker/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vosttro Asset Tracker',
      debugShowCheckedModeBanner: false, // Opcional: remove a faixa de debug no canto superior direito

theme: ThemeData(
  fontFamily: 'Inter',
  useMaterial3: true,
  brightness: Brightness.light,

  // 🔵 ESQUEMA DE CORES GLOBAL (REMOVE O ROXO)
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue,
    primary: Colors.blue[700]!,
    secondary: Colors.blue[600]!,
    tertiary: Colors.blue[500]!,
  ),

  scaffoldBackgroundColor: Colors.grey[50],

  // 🔵 APP BAR
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.blue[700],
    foregroundColor: Colors.white,
    elevation: 4,
    titleTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),

  // 🔵 ELEVATED BUTTON
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue[700],
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  ),

  // 🔵 TEXT BUTTON
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Colors.blue[700],
    ),
  ),

  // 🔵 INPUTS / TEXTFIELDS
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey[400]!),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey[400]!),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: Colors.blue[700]!,
        width: 2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    labelStyle: TextStyle(color: Colors.grey[700]),
    hintStyle: TextStyle(color: Colors.grey[500]),
    contentPadding: const EdgeInsets.symmetric(
      vertical: 12,
      horizontal: 16,
    ),
  ),

  // 🔵 CARDS
  cardTheme: CardThemeData(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    margin: const EdgeInsets.all(8),
  ),
),


      // Home agora será um StreamBuilder que escuta as mudanças de autenticação
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          // Se ainda estamos esperando a conexão com o Firebase Auth
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(), // Mostra um loading
              ),
            );
          }
          // Se o usuário estiver logado (snapshot.hasData ou snapshot.data != null)
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen(); // Redireciona para a tela principal
          }
          // Se o usuário não estiver logado
          return const LoginScreen(); // Redireciona para a tela de login
        },
      ),
    );
  }
}
