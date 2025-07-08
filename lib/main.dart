import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/splash_screen.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'services/updater.dart';

// 🔔 Notification Plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// 🔕 Background notification handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📬 Background notification: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Supabase.initialize(
    url: 'https://siwidxwgojsyyenzaena.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNpd2lkeHdnb2pzeXllbnphZW5hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY2MTY2NzksImV4cCI6MjA1MjE5MjY3OX0.s1uzCefy3VJC2DfNPdBeWWqmOm46KGXDZE9nYBfH3hY',
  );

  // 🔄 Windows Updater check only for Windows
  if (Platform.isWindows) {
    await Updater(
      versionUrl: 'https://siwidxwgojsyyenzaena.supabase.co/storage/v1/object/public/metadata/version.json',
    ).checkForUpdate();
  }

  // ✅ Firebase only on mobile platforms
  if (Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    String? token = await messaging.getToken();
    print('📱 Device FCM Token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        flutterLocalNotificationsPlugin.show(
          0,
          message.notification!.title,
          message.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel',
              'General',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
            ),
          ),
        );
      }
    });
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('mr'),
        Locale('ta'),
        Locale('bn'),
        Locale('pa'),
        Locale('es'),
        Locale('fr'),
        Locale('de'),
        Locale('it'),
        Locale('ar'),
        Locale('ja'),
        Locale('ru'),
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
      title: 'Invexa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      initialRoute: '/splash',
      onGenerateRoute: _generateRoute,
    );
  }

  Route<dynamic> _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return MaterialPageRoute(builder: (_) => SplashScreen());
      case '/':
        return MaterialPageRoute(builder: (_) => AuthChecker());
      case '/home':
        return MaterialPageRoute(builder: (_) => HomePage());
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

        // ✅ User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!.session?.user;

          if (user != null) {
            // ✅ Ensure FCM token is saved before navigating to HomePage
            return FutureBuilder(
              future: _updateFcmToken(user.id),
              builder: (context, tokenSnapshot) {
                if (tokenSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                } else {
                  return HomePage();
                }
              },
            );
          }
        }

        // ❌ Not logged in
        return const LoginPage();
      },
    );
  }

  /// ✅ Store FCM token in Supabase `profiles` table
  Future<void> _updateFcmToken(String userId) async {
    if (Platform.isAndroid || Platform.isIOS) {
      String? token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', userId);
      }
    }
  }

}
