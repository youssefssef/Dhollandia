// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dhollandia/Home_page.dart';
import 'package:dhollandia/addRapport.dart';
import 'package:dhollandia/calendrier.dart';
import 'package:dhollandia/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({
    Key? key,
  }) : super(key: key);

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      Uri.parse('https://liya.is-tech.app/api/logout'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      if (response.statusCode == 200) {
        print('Logged out successfully');
        prefs.remove('token');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
          ModalRoute.withName('/'),
        );
      } else {
        throw Exception('Failed to log out');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez vérifier la connexion pour vous déconnecter'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0XFFf96006),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          // ignore: prefer_const_literals_to_create_immutables
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 130.0),
              child: Center(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Image.asset(
                      'assets/png.png',
                      color: Colors.white,
                      scale: 6,
                    )),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.09),
              child: ListTile(
                leading: Icon(
                  Icons.home,
                  color: Colors.white,
                ),
                title: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Home',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
                },
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.article,
                color: Colors.white,
              ),
              title: Text(
                'Rapports',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AddRepport()));
              },
            ),
            ListTile(
              leading: Icon(
                Icons.calendar_today,
                color: Colors.white,
              ),
              title: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Calendrier',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendrierPage()));
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(45, 90, 0, 0),
              child: Container(
                height: 50,
                width: 150,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(width: 2, color: Colors.white)),
                child: TextButton.icon(
                    onPressed: () {
                      _logout();
                    },
                    icon: Icon(
                      Icons.logout,
                      color: Colors.white,
                    ),
                    label: Text(
                      'LogOut',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
