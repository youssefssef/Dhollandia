import 'package:animated_splash_screen/animated_splash_screen.dart';

import 'package:dhollandia/Home_page.dart';
import 'package:dhollandia/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'widget/notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => Counter(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool userCheck = false;
  @override
  void initState() {
    super.initState();
    checkUser();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
        backgroundColor: Colors.white,
        // ignore: prefer_const_literals_to_create_immutables
        splash: Column(children: [
          FractionallySizedBox(
            widthFactor: 0.6,
            child: Image.asset('assets/png.png'),
          ),
          const SizedBox(height: 50),
          const SpinKitCubeGrid(
            size: 40,
            color: Color(0xFFf96006),
          ),
        ]),
        splashIconSize: 400,
        splashTransition: SplashTransition.fadeTransition,
        duration: 2500,
        nextScreen: userCheck ? HomePage() : LoginPage());
  }

  void checkUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      setState(() {
        userCheck = !userCheck;
      });
    } else {
      userCheck = false;
    }
  }
}
