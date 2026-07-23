import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:myroute_web/firebase_options.dart';
import 'package:myroute_web/login_page.dart'; // Login Page එක import කරන්න

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyRoute Web',
      theme: ThemeData(
        brightness: Brightness.dark, // Web Dashboard එකට අඳුරු තේමාව ගැලපේ
        primarySwatch: Colors.blue,
      ),
      // මෙහිදී DashboardPage වෙනුවට LoginPage ලබා දෙන්න
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
