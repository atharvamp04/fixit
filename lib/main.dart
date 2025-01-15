import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (configuration remains untouched)
  await Supabase.initialize(
    url: 'https://siwidxwgojsyyenzaena.supabase.co', // Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNpd2lkeHdnb2pzeXllbnphZW5hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY2MTY2NzksImV4cCI6MjA1MjE5MjY3OX0.s1uzCefy3VJC2DfNPdBeWWqmOm46KGXDZE9nYBfH3hY', // Supabase Anon Key
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chatbot App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Initial route set to login
      initialRoute: '/login',
      onGenerateRoute: _generateRoute,
    );
  }

  Route<dynamic> _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => AuthChecker());
      case '/home':
        return MaterialPageRoute(builder: (_) => HomePage());
      case '/login':
        return MaterialPageRoute(builder: (_) => LoginPage());
      case '/signup':
        return MaterialPageRoute(builder: (_) => SignupPage());
      default:
      // Fallback route for undefined routes
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text(
                '404: Page Not Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
    }
  }
}

class AuthChecker extends StatelessWidget {
  final SupabaseClient supabaseClient = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabaseClient.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!.session?.user;
          if (user != null) {
            return HomePage(); // Navigate to home if the user is logged in
          }
        }

        // Navigate to login if not authenticated
        return LoginPage();
      },
    );
  }
}
