import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'logic/document_bloc/document_bloc.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp( 
    BlocProvider(
      create: (context) => DocumentBloc(),
      child: const DocEaseApp(),
    ),
  );
}

class DocEaseApp extends StatelessWidget {
  const DocEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocEase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        // Keeping your original branding colors
        scaffoldBackgroundColor: const Color(0xFF0B0E2C),
        cardTheme: const CardThemeData(color: Color(0xFF121430)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF061F33),
          elevation: 0,
        ),
      ),
      // Starting with your original Splash Screen
      home: const SplashScreen(),
    );
  }
}