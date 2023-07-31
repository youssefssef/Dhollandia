// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, prefer_const_literals_to_create_immutables, unused_field, prefer_final_fields, unnecessary_import, implementation_imports, avoid_print, unused_local_variable, use_build_context_synchronously, unnecessary_null_comparison, prefer_const_declarations

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dhollandia/Home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscureText = true;
  bool _loading = false;

  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final response = await http.post(
      Uri.parse('https://liya.is-tech.app/api/login'),
      headers: <String, String>{
        'content-type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'email': _emailController.text,
        'password': _passwordController.text,
      }),
    );

    final ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      if (response.statusCode == 200) {
        final token = jsonDecode(response.body)['token'];
        print('Token: $token');

        final prefs = await SharedPreferences.getInstance();
        prefs.setString('token', token);

        // Redirect the user to the home page or any authenticated page
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
        setState(() {
          _loading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('email ou mot de passe invalide'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez vérifier la connexion pour vous connecter'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: Image.asset('assets/png.png', width: 220)),
          ),
          SizedBox(height: 30),
          Container(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height / 1.9, maxHeight: double.infinity),
            width: MediaQuery.of(context).size.width / 1.12,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Color(0xFFf96006)),
            child: Form(
              key: _formKey,
              child: Column(children: [
                SizedBox(height: 20),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Connexion ',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                SizedBox(height: 10),
                Divider(
                  thickness: 1,
                  color: Colors.white,
                  endIndent: 20,
                  indent: 20,
                ),
                SizedBox(height: 25),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25.0),
                  child: TextFormField(
                    controller: _emailController,
                    validator: (value) => value!.isEmpty ? 'veuillez saisir une adresse e-mail valide' : null,
                    decoration: InputDecoration(
                      enabledBorder:
                          OutlineInputBorder(borderSide: BorderSide(color: Colors.black), borderRadius: BorderRadius.circular(25)),
                      focusedBorder:
                          OutlineInputBorder(borderSide: BorderSide(color: Colors.white), borderRadius: BorderRadius.circular(25)),
                      prefixIcon: Icon(
                        Icons.email_rounded,
                        color: Colors.white,
                      ),
                      hintText: 'Entrez votre email..',
                      hintStyle: TextStyle(fontSize: 14),
                      errorStyle: TextStyle(color: Colors.yellow),
                      filled: true,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25.0),
                  child: TextFormField(
                    controller: _passwordController,
                    validator: (value) => value!.isEmpty ? 'veuillez entrer le mot de passe' : null,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      enabledBorder:
                          OutlineInputBorder(borderSide: BorderSide(color: Colors.black), borderRadius: BorderRadius.circular(25)),
                      focusedBorder:
                          OutlineInputBorder(borderSide: BorderSide(color: Colors.white), borderRadius: BorderRadius.circular(25)),
                      prefixIcon: Icon(
                        Icons.lock_clock_rounded,
                        color: Colors.white,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                        child: Icon(
                          _obscureText ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white,
                        ),
                      ),
                      hintText: 'Entrez votre mot de passe..',
                      hintStyle: TextStyle(fontSize: 14),
                      errorStyle: TextStyle(
                        color: Colors.yellow,
                      ),
                      filled: true,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Text(
                        'Connecter ',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: InkWell(
                        onTap: () {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              _loading = true;
                            });
                            _login();
                          }
                        },
                        child: _loading
                            ? SpinKitDoubleBounce(
                                size: 40,
                                color: Colors.white,
                              )
                            : CircleAvatar(
                                radius: 40,
                                child: Icon(Icons.arrow_circle_right, size: 70),
                              ),
                      ),
                    )
                  ],
                )
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
