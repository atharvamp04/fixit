import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your project details
  await Supabase.initialize(
    url: 'https://siwidxwgojsyyenzaena.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNpd2lkeHdnb2pzeXllbnphZW5hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY2MTY2NzksImV4cCI6MjA1MjE5MjY3OX0.s1uzCefy3VJC2DfNPdBeWWqmOm46KGXDZE9nYBfH3hY',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Supabase Auth App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => AuthChecker(),
        '/home': (context) => HomePage(),
      },
    );
  }
}

class AuthChecker extends StatefulWidget {
  @override
  _AuthCheckerState createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    // Delay the authentication check until Supabase is fully initialized.
    _initialization = Future.value();

  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final user = Supabase.instance.client.auth.currentUser;
        return user == null ? LoginPage() : HomePage();
      },
    );
  }
}
