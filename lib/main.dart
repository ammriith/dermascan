import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'landing_page.dart';
import 'patient/patient_register.dart';
import 'about_us.dart';
import 'auth_wrapper.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Dermascan',
          
          // Theme configuration - uses provider
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

          // 🔹 Initial Screen (Session Check)
          home: const AuthWrapper(),

          // 🔹 App Routes (recommended)
          routes: {
            '/landing': (context) => const LandingPage(),
            '/register': (context) => const RegisterPage(),
            '/about': (context) => const AboutUsPage(),
          },
        );
      },
    );
  }
}
