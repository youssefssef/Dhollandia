// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, unused_field, prefer_final_fields, avoid_print, unnecessary_null_comparison, non_constant_identifier_names, no_leading_underscores_for_local_identifiers, prefer_const_declarations, unnecessary_null_in_if_null_operators, unused_local_variable, unrelated_type_equality_checks

import 'dart:convert';
import 'dart:io';

import 'package:dhollandia/Home_page.dart';
import 'package:dhollandia/sqldb.dart';
import 'package:dhollandia/widget/notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_zoom_drawer/config.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:quickalert/quickalert.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'menuPage.dart';

class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key});

  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  ZoomDrawerController zoomDrawerController = ZoomDrawerController();
  List<Map<String, dynamic>> _examens = [];
  List<String> report = [];
  bool _isLoading = true;
  bool CameraIconVisible = false;
  bool connexionCheck = false;
  bool sendExamLoading = false;

  //TextEditingController observationController = TextEditingController();
  List<TextEditingController> observationControllers = [];
  int _total = 0;
  List<List<String>> questionLists = [];

  //function to open the camera
  Future<File?> pickImage() async {
    var pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    return pickedFile != null ? File(pickedFile.path) : null;
  }

  @override
  void initState() {
    super.initState();
    _initializeQuestionLists();
  }

  Future<void> _initializeQuestionLists() async {
    await _fetchExamenNames();

    // Create empty lists based on the value of _total
    for (int i = 0; i < _total; i++) {
      questionLists.add([]);
    }
    observationControllers = List.generate(questionLists.length, (_) => TextEditingController());
  }

  //function to get exams and question
  Future<void> _fetchExamenNames() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      // No internet connection, fetch data from local database
      final sqlDb = SqlDb();
      final List<Map<String, dynamic>> examens = await sqlDb.getData('exams');
      setState(() {
        connexionCheck = true;
      });

      final List<Map<String, dynamic>> processedExamens = [];

      for (final examenData in examens) {
        final List<dynamic> questionsData = examenData['questions'] != null ? jsonDecode(examenData['questions']) : [];
        final List<Map<String, dynamic>> questions = questionsData
            .map<Map<String, dynamic>>(
              (question) => {
                'id': question['id'] ?? 0,
                'question': question['question'] ?? '',
              },
            )
            .toList();

        final examen = {
          'id': examenData['id'],
          'name': examenData['exam_name'] ?? '',
          'questions': questions,
          'icon': examenData['icon'] ?? '',
        };

        processedExamens.add(examen);
      }
      printExams();
      setState(() {
        _examens = processedExamens;
        _total = _examens.length;
        _isLoading = false;
      });
    } else {
      // Internet connection available, fetch data from API
      final response = await http.get(
        Uri.parse('https://liya.is-tech.app/api/Examen'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> examensData = data.values.first;
        final List<Map<String, dynamic>> examens = [];

        for (final examenData in examensData) {
          final List<Map<String, dynamic>> questions = examenData['question'] != null && examenData['question'].isNotEmpty
              ? examenData['question']
                  .map<Map<String, dynamic>>(
                    (question) => {'id': question['id'], 'question': question['question']},
                  )
                  .toList()
              : [];

          final examen = {
            'id': examenData['id'],
            'name': examenData['examen'],
            'questions': questions,
            'icon': examenData['icon'] ?? '',
          };

          examens.add(examen);
        }

        final int total = data['total'];
        print(total);

        setState(() {
          _examens = examens;
          _total = total;
          _isLoading = false;
          connexionCheck = false;
        });

        // Save the fetched data to the local database
        clean('exams');
        for (final examen in examens) {
          if (examen['icon'] != null && examen['icon'].isNotEmpty) {
            final String imageUrl = "https://liya.is-tech.app/storage/${examen['icon']}";
            final String imageName = examen['icon'].split('/').last;
            final String localPath = await _downloadImage(imageUrl, imageName);
            saveExams(
              examen['id'],
              examen['name'],
              jsonEncode(examen['questions']),
              localPath,
            );
          } else {
            saveExams(
              examen['id'],
              examen['name'],
              jsonEncode(examen['questions']),
              '',
            );
          }
        }

        printExams();
      } else {
        setState(() {
          _isLoading = false; // set loading to false if there is an error
        });

        throw Exception('Failed to fetch examen names');
      }
    }
  }

  //to download the image for offline using
  Future<String> _downloadImage(String imageUrl, String imageName) async {
    final response = await http.get(Uri.parse(imageUrl));
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/$imageName';
    final File imageFile = File(imagePath);
    await imageFile.writeAsBytes(response.bodyBytes);
    return imagePath;
  }

  //function to send answers
  Future<void> sendExams(BuildContext context) async {
    int? interventionId = Provider.of<Counter>(context, listen: false).interventionId;
    String latitude = Provider.of<Counter>(context, listen: false).latitude;
    String longitude = Provider.of<Counter>(context, listen: false).longitude;
    String date = DateFormat('yyyy-MM-dd KK:mm:ss').format(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final url = Uri.parse('https://liya.is-tech.app/api/Intervention/$interventionId');
    final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
    final body = {"lat": latitude, "lng": longitude, "date": date, "answer": questionLists};

    final ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      //there  is n connection
      if (questionLists.isNotEmpty) {
        saveReport(interventionId, latitude, longitude, jsonEncode(questionLists), date);
        QuickAlert.show(
          context: context,
          type: QuickAlertType.success,
          barrierDismissible: false,
          title: 'succès',
          text: 'le rapport a été créé avec succès',
          confirmBtnColor: Colors.deepOrange,
          onConfirmBtnTap: () {
            Navigator.of(context).pop();
            Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
          },
        );
      } else {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.error,
          barrierDismissible: false,
          title: 'erreur',
          text: "assurez-vous d'avoir répondu aux questions",
          confirmBtnColor: Colors.deepOrange,
          onConfirmBtnTap: () {
            Navigator.of(context).pop();
            setState(() {
              sendExamLoading = false;
            });
          },
        );
      }
    } else {
      final bool isTableEmpty = await TableCheck('reports');

      if (!isTableEmpty) {
        final sqlDb = SqlDb();
        List<Map<String, dynamic>> reports = await sqlDb.getData('reports');

        for (final report in reports) {
          final reportId = report['intervention_id'];
          final reportLatitude = report['lat'];
          final reportLongitude = report['lng'];
          final reportAnswer = jsonDecode(report['answers']);
          final reportDate = report['time'];

          final reportBody = {"lat": reportLatitude, "lng": reportLongitude, "answer": reportAnswer, "date": reportDate};
          final reportResponse = await http.put(url, headers: headers, body: json.encode(reportBody));
          if (reportResponse.statusCode == 200) {
            print('Data sent successfully');
            sqlDb.delete(reports, reportId);
            final responseData = json.decode(reportResponse.body);
            final reportPdfPath = responseData['path'];
            final baseUrl = 'https://liya.is-tech.app/storage/images/';
            final reportPdfUrl = baseUrl + reportPdfPath;
            await prefs.setString('reportPdfUrl_$interventionId', reportPdfUrl);
            print(reportPdfUrl);
          } else {
            print('failed to send the data. Error : ${reportResponse.statusCode}');
          }
        }
        clean('reports');
      }
      if (questionLists.isNotEmpty) {
        final response = await http.put(url, headers: headers, body: json.encode(body));

        if (response.statusCode == 200) {
          // Request successful, handle the response data
          print('Data sent successfully');
          questionLists.clear();
          final responseData = json.decode(response.body);
          final reportPdfPath = responseData['path'];

          final baseUrl = 'https://liya.is-tech.app/storage/images/';
          final reportPdfUrl = baseUrl + reportPdfPath;

          await prefs.setString('reportPdfUrl_$interventionId', reportPdfUrl);
          print(reportPdfUrl);
          QuickAlert.show(
            context: context,
            type: QuickAlertType.success,
            barrierDismissible: false,
            title: 'succès',
            text: 'le rapport a été créé avec succès',
            confirmBtnColor: Colors.deepOrange,
            onConfirmBtnTap: () {
              Navigator.of(context).pop();
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
            },
          );
        } else {
          // Request failed, handle the error
          print('Failed to send data. Error: ${response.statusCode}');
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            barrierDismissible: false,
            title: 'erreur',
            text: "Quelque chose c'est mal passé. Merci d'essayer plus tard",
            confirmBtnColor: Colors.deepOrange,
            onConfirmBtnTap: () {
              Navigator.of(context).pop();
              setState(() {
                sendExamLoading = false;
              });
            },
          );
        }
      } else {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.warning,
          barrierDismissible: false,
          title: 'erreur',
          text: "assurez-vous d'avoir répondu aux questions",
          confirmBtnColor: Colors.deepOrange,
          onConfirmBtnTap: () {
            Navigator.of(context).pop();
            setState(() {
              sendExamLoading = false;
            });
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZoomDrawer(
        controller: zoomDrawerController,
        menuBackgroundColor: Color(0XFFf96006),
        openCurve: Curves.fastOutSlowIn,
        showShadow: true,
        borderRadius: 24,
        angle: 0.0,
        menuScreen: MenuPage(),
        mainScreen: Scaffold(
          backgroundColor: Colors.grey[200],
          appBar: AppBar(
            backgroundColor: Colors.orangeAccent,
            leading: IconButton(
                onPressed: () {
                  zoomDrawerController.toggle!();
                },
                icon: Icon(
                  Icons.menu,
                  color: Colors.white,
                )),
            centerTitle: true,
            title: const Text(
              "Examens",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 23),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                _isLoading
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: SpinKitThreeBounce(
                            size: 40,
                            color: Color(0xFFf96006),
                          ),
                        ),
                      )
                    : GridView.count(
                        shrinkWrap: true,
                        primary: false,
                        padding: const EdgeInsets.all(30),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                        children: _examens.map((examen) {
                          List<bool> _selected = List.filled(examen['questions'].length, false);
                          List<bool> _selectedX = List.filled(examen['questions'].length, false);
                          List<bool> _seletedIndex = List.filled(examen['questions'].length, false);
                          List<bool> _colorIndex = List.filled(examen['questions'].length, false);
                          List<bool> _observationStatus = [];

                          //keys for observation visiblity
                          List<GlobalKey<FormState>> observationKeys = List.generate(
                            _examens.length,
                            (index) => GlobalKey<FormState>(),
                          );

                          void resetList() {
                            setState(() {
                              for (int i = 0; i < _selected.length; i++) {
                                _selected[i] = false;
                                _selectedX[i] = false;
                                _seletedIndex[i] = false;
                              }
                            });
                          }

                          return GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (BuildContext context) {
                                  return StatefulBuilder(builder: (context, setState) {
                                    return AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: Text(
                                        examen['name'],
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: examen['questions'].asMap().entries.map<Widget>((entry) {
                                            final index = entry.key;
                                            final question = entry.value;

                                            return Padding(
                                              padding: const EdgeInsets.only(top: 5.0),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    constraints: BoxConstraints(
                                                        minHeight: MediaQuery.of(context).size.height * 0.07, maxHeight: double.infinity),
                                                    width: MediaQuery.of(context).size.width / 1.1,
                                                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(5)),
                                                    child: Padding(
                                                      padding: EdgeInsets.all(10),
                                                      child: Center(
                                                        child: Row(
                                                          children: [
                                                            SizedBox(
                                                              width: MediaQuery.of(context).size.width * 0.35,
                                                              child: Text(
                                                                question['question'],
                                                              ),
                                                            ),
                                                            Spacer(),
                                                            InkWell(
                                                              onTap: () {
                                                                setState(
                                                                  () {
                                                                    _selected[index] = !_selected[index];
                                                                    if (_selected[index] == true) {
                                                                      _selectedX[index] = false;

                                                                      //avoid two answers for the same question
                                                                      if (_seletedIndex[index] == true) {
                                                                        for (var i = 0; i < questionLists.length; i++) {
                                                                          final currentList = questionLists[i];
                                                                          if (currentList.isNotEmpty &&
                                                                              currentList[0] == '${question['id']}') {
                                                                            currentList.clear();
                                                                            currentList.add('${question['id']}');
                                                                            currentList.add('${_selected[index]}');
                                                                          }
                                                                        }
                                                                      } else {
                                                                        for (var i = 0; i < questionLists.length; i++) {
                                                                          final currentList = questionLists[i];
                                                                          if (currentList.isEmpty) {
                                                                            currentList.add('${question['id']}');
                                                                            currentList.add('${_selected[index]}');
                                                                            _seletedIndex[index] = true;
                                                                            break;
                                                                          }
                                                                        }
                                                                      }
                                                                    } else {
                                                                      for (var i = 0; i < questionLists.length; i++) {
                                                                        final currentList = questionLists[i];
                                                                        if (currentList.isNotEmpty &&
                                                                            currentList[0] == '${question['id']}') {
                                                                          currentList.clear();
                                                                          _selected[index] = false;
                                                                          break;
                                                                        }
                                                                      }
                                                                    }
                                                                    print(questionLists);
                                                                  },
                                                                );
                                                              },
                                                              child: Icon(Icons.check_circle,
                                                                  color: _selected[index] ? Colors.green : Colors.black),
                                                            ),
                                                            InkWell(
                                                              onTap: () {
                                                                setState(
                                                                  () {
                                                                    _selectedX[index] = !_selectedX[index];
                                                                    if (_selectedX[index] == true) {
                                                                      _selected[index] = false;
                                                                      _colorIndex == true;
                                                                      _observationStatus.add(false);
                                                                      pickImage().then((File? pickedFile) {
                                                                        if (pickedFile != null) {
                                                                          pickedFile.readAsBytes().then((imageBytes) {
                                                                            final image64 = base64Encode(imageBytes);
                                                                            if (_seletedIndex[index] == true) {
                                                                              for (var i = 0; i < questionLists.length; i++) {
                                                                                final currentList = questionLists[i];
                                                                                if (currentList.isNotEmpty &&
                                                                                    currentList[0] == '${question['id']}') {
                                                                                  currentList.clear();
                                                                                  currentList.add('${question['id']}');
                                                                                  currentList.add('${_selected[index]}');
                                                                                  currentList.add(image64.toString());
                                                                                }
                                                                              }
                                                                            } else {
                                                                              for (var i = 0; i < questionLists.length; i++) {
                                                                                final currentList = questionLists[i];
                                                                                if (currentList.isEmpty) {
                                                                                  currentList.add('${question['id']}');
                                                                                  currentList.add('${_selected[index]}');
                                                                                  currentList.add(image64.toString());
                                                                                  _seletedIndex[index] = true;
                                                                                  break;
                                                                                }
                                                                              }
                                                                            }
                                                                          });
                                                                        }
                                                                      });
                                                                    } else {
                                                                      for (var i = 0; i < questionLists.length; i++) {
                                                                        final currentList = questionLists[i];
                                                                        if (currentList.isNotEmpty &&
                                                                            currentList[0] == '${question['id']}') {
                                                                          currentList.clear();
                                                                          _seletedIndex[index] = false;
                                                                          break;
                                                                        }
                                                                      }
                                                                    }
                                                                    print(questionLists);
                                                                  },
                                                                );
                                                              },
                                                              child:
                                                                  Icon(Icons.cancel, color: _selectedX[index] ? Colors.red : Colors.black),
                                                            ),
                                                            Visibility(
                                                              visible: _selectedX[index],
                                                              child: GestureDetector(
                                                                onTap: () {
                                                                  setState(() {
                                                                    _selectedX[index] = !_selectedX[index];
                                                                    if (_selectedX[index]) {
                                                                      _selected[index] = false;
                                                                      pickImage().then((File? pickedFile) {
                                                                        if (pickedFile != null) {
                                                                          pickedFile.readAsBytes().then((imageBytes) {
                                                                            final image64 = base64Encode(imageBytes);
                                                                            for (var i = 0; i < questionLists.length; i++) {
                                                                              final currentList = questionLists[i];
                                                                              if (currentList.isNotEmpty &&
                                                                                  currentList[0] == '${question['id']}') {
                                                                                currentList.add(image64.toString());
                                                                                break;
                                                                              }
                                                                            }
                                                                          });
                                                                        }
                                                                      });
                                                                    }
                                                                    print(questionLists);
                                                                  });
                                                                },
                                                                child: Icon(Icons.camera, color: Colors.red),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Visibility(
                                                    visible: _selectedX[index],
                                                    child: Form(
                                                      key: observationKeys[index],
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: TextFormField(
                                                                controller: observationControllers[index],
                                                                minLines: null,
                                                                maxLines: null,
                                                                validator: (value) =>
                                                                    value!.isEmpty ? 'ce champion ne devrait pas être vide' : null,
                                                                decoration: const InputDecoration(
                                                                  border: UnderlineInputBorder(),
                                                                  labelText: 'Observation',
                                                                ),
                                                              ),
                                                            ),
                                                            IconButton(
                                                                onPressed: () {
                                                                  if (observationKeys[index].currentState!.validate()) {
                                                                    for (var i = 0; i < questionLists.length; i++) {
                                                                      final currentList = questionLists[i];
                                                                      if (currentList.isNotEmpty && currentList[0] == '${question['id']}') {
                                                                        currentList.add(' ${observationControllers[index].text}');
                                                                        break;
                                                                      }
                                                                    }
                                                                    if (observationControllers[index].text.isNotEmpty) {
                                                                      setState(() {
                                                                        _observationStatus[index] = true;
                                                                        _colorIndex[index] = !_colorIndex[index];
                                                                      });
                                                                    }
                                                                  }
                                                                },
                                                                icon: Icon(
                                                                  Icons.send,
                                                                  color: _colorIndex[index] ? Colors.green : Colors.deepOrange,
                                                                ))
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Divider(
                                                    thickness: 1,
                                                  )
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                            onPressed: () {
                                              for (var i = 0; i < questionLists.length; i++) {
                                                final currentList = questionLists[i];
                                                if (currentList.isNotEmpty) {
                                                  currentList.clear();
                                                }
                                              }
                                              resetList();
                                              Navigator.pop(context);
                                            },
                                            child: Text(
                                              'annuler',
                                              style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
                                            )),
                                        TextButton(
                                            onPressed: () {
                                              print(_observationStatus);
                                              if (_observationStatus.isNotEmpty) {
                                                if (_observationStatus.every((element) => element)) {
                                                  Navigator.pop(context);
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text("assurez-vous d'avoir enregistré toutes les observations"),
                                                    ),
                                                  );
                                                }
                                              } else {
                                                Navigator.pop(context);
                                                print(questionLists);
                                              }
                                            },
                                            child: Text(
                                              'sauvegarder',
                                              style: TextStyle(color: Colors.deepOrange, fontSize: 14, fontWeight: FontWeight.bold),
                                            )),
                                      ],
                                    );
                                  });
                                },
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (examen['icon'] != null && examen['icon'].isNotEmpty)
                                      connexionCheck
                                          ? Image.file(
                                              File('${examen['icon']}'),
                                              width: 30,
                                              height: 30,
                                            )
                                          : Image.network(
                                              "https://liya.is-tech.app/storage/${examen['icon']}",
                                              width: 30,
                                              height: 30,
                                            ),
                                    Text(
                                      examen['name'],
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                SizedBox(height: 70),
                Row(
                  // ignore: prefer_const_literals_to_create_immutables
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 40),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width / 2,
                        child: Text(
                          'Enregistrer le Rapport',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Spacer(),
                    Padding(
                      padding: EdgeInsets.only(right: 30, bottom: 10),
                      child: InkWell(
                        onTap: () {
                          sendExams(context);
                          setState(() {
                            sendExamLoading = true;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: sendExamLoading
                              ? SpinKitDoubleBounce(
                                  size: 35,
                                  color: Color(0xFFf96006),
                                )
                              : CircleAvatar(
                                  backgroundColor: Color(0xFFf96006),
                                  radius: 30,
                                  child: Icon(Icons.arrow_circle_right, color: Colors.white, size: 45)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //save exmas data to the table exams
  void saveExams(examenId, examName, questions, icon) async {
    final sqlDb = SqlDb();
    await sqlDb.addExam(examenId, examName, questions ?? [], icon ?? '');
  }

  //save the report answers to the table reports
  void saveReport(id, latitude, longitude, answer, date) async {
    final sqlDb = SqlDb();
    await sqlDb.addReport(id, latitude, longitude, answer, date);
  }

  void printExams() async {
    final sqlDb = SqlDb();
    final exams = await sqlDb.getData('exams');
    for (final exam in exams) {
      print('id : ${exam['examen_id']}, name : ${exam['exam_name']}, qst: ${exam['questions']}, icon: ${exam['icon']}');
    }
  }

  void printAnswers() async {
    final sqlDb = SqlDb();
    final reports = await sqlDb.getData('reports');
    for (final report in reports) {
      print(
          'id : ${report['intervention_id']}, lat : ${report['lat']}, lng: ${report['lng']}, answer: ${report['answers']}, time : ${report['time']}');
    }
  }

  //to check any table if its empy
  Future<bool> TableCheck(table) async {
    final sqlDb = SqlDb();
    return await sqlDb.isTableEmpty(table);
  }

  //to clean the table from any data
  void clean(table) async {
    final sqlDb = SqlDb();
    await sqlDb.cleanTable(table);
    print('the table had been cleaned');
  }
}
