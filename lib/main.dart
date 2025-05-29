import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Supabase.initialize(
    url: 'https://siwidxwgojsyyenzaena.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNpd2lkeHdnb2pzeXllbnphZW5hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY2MTY2NzksImV4cCI6MjA1MjE5MjY3OX0.s1uzCefy3VJC2DfNPdBeWWqmOm46KGXDZE9nYBfH3hY',
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'), // English
        Locale('hi'), // Hindi
        Locale('mr'), // Marathi
        Locale('ta'), // Tamil
        Locale('bn'), // Bengali
        Locale('pa'), // Punjabi
        Locale('es'), // Spanish
        Locale('fr'), // French
        Locale('de'), // German
        Locale('it'),
        Locale('ar'),
        Locale('de'),
        Locale('es'),
        Locale('ja'),
        Locale('ru'),
        Locale('ta'),
        Locale('zh'),
      ],
      path: 'assets/langs',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fixit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      initialRoute: '/',
      onGenerateRoute: _generateRoute,
    );
  }

  Route<dynamic> _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) =>  AuthChecker());
      case '/home':
        return MaterialPageRoute(builder: (_) =>  HomePage());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignupPage());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text(
                'not_found'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
    }
  }
}

class AuthChecker extends StatelessWidget {
   AuthChecker({super.key});
  final SupabaseClient supabaseClient = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabaseClient.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                '${'error'.tr()}: ${snapshot.error}',
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!.session?.user;
          if (user != null) {
            return  HomePage(); // Logged in
          }
        }

        return const LoginPage(); // Not logged in
      },
    );
  }
}
