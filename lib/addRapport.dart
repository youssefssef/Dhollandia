// ignore_for_file: prefer_const_constructors, prefer_final_fields, avoid_unnecessary_containers, sized_box_for_whitespace, unused_local_variable, await_only_futures, unused_field

import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dhollandia/calendrier.dart';
import 'package:dhollandia/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_zoom_drawer/config.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'menuPage.dart';
import 'widget/notifier.dart';

class AddRepport extends StatefulWidget {
  const AddRepport({super.key});

  @override
  State<AddRepport> createState() => _AddRepportState();
}

class _AddRepportState extends State<AddRepport> {
  ZoomDrawerController zoomDrawerController = ZoomDrawerController();
  int selectedYear = DateTime.now().year;
  bool interventionEmpty = true;
  int interventionTerminer = 0;
  List<Map<String, dynamic>> interventions = [];
  List<Map<String, dynamic>> interventionsTerminer = [];
  bool connexionCheck = false;
  bool indicator = true;
  RefreshController _refreshController = RefreshController(initialRefresh: false);

  //location methode
  Future<void> checkPermission() async {
    if (await Permission.location.serviceStatus.isEnabled) {
    } else {}
    var status = await Permission.location.status;
    if (status.isGranted) {
    } else {
      Map<Permission, PermissionStatus> status = await [
        Permission.location,
      ].request();
    }
  }

  final db = SqlDb();
  Future<List<Map<String, dynamic>>>? _answersList;

  @override
  void initState() {
    super.initState();
    //_answersList = db.getAnswers();
    fetchInterventions();
  }

  //to get all the intervention already terminer
  Future<void> fetchInterventions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final int startYear = selectedYear;
    final int endYear = selectedYear + 4;
    int totalTerminerInterventions = 0;
    bool interventionsEmpty = true;

    final ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      // No internet connection, fetch data from local database
      final sqlDb = SqlDb();
      List<Map<String, dynamic>> interventions = await sqlDb.getData('interventions');
      setState(() {
        connexionCheck = true;
      });

      final List<Map<String, dynamic>> terminerInterventions = [];

      for (final intervention in interventions) {
        final contratId = intervention['contrat_id'];
        final dateIntervention = intervention['date_intervention'];
        final interventionId = intervention['id'];
        final dateValidation = intervention['date_validation'];
        final status = intervention['status'];
        final vehiculeImage = intervention['vehicule_image'];
        final vehiculeMatricule = intervention['matricule'];
        final societeName = intervention['societe_name'];

        if (status == 'Terminer') {
          totalTerminerInterventions++;
          terminerInterventions.add({
            'id': interventionId,
            'contrat_id': contratId,
            'date_intervention': dateIntervention,
            'date_validation': dateValidation,
            'status': status,
            'matricule': vehiculeMatricule,
            'image': vehiculeImage,
            'societe': societeName,
          });
          interventionsEmpty = false;
        }
      }

      setState(() {
        interventionsTerminer = terminerInterventions;
        interventionTerminer = terminerInterventions.length;
        interventionEmpty = terminerInterventions.isEmpty;
        indicator = false;
      });
    } else {
      // Internet connection available, fetch data from API
      clean('interventions');
      for (int year = startYear; year <= endYear; year++) {
        final response = await http.get(
          Uri.parse('https://liya.is-tech.app/api/Intervention/$year'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final List<Map<String, dynamic>> interventionList = List<Map<String, dynamic>>.from(data);

          for (final intervention in interventionList) {
            final contratId = intervention['contrat_id'];
            final dateIntervention = intervention['date_intervention'];
            final interventionId = intervention['id'];
            final dateValidation = intervention['date_validation'];
            final status = intervention['status'] != null ? intervention['status']['status'] : '';

            final vehicule = intervention['contrat']['vehicule'];
            final type = intervention['contrat']['vehicule']['typevehicule'];
            final vehiculeImage = vehicule != null && vehicule['image'] != null ? vehicule['image'] : '';
            final vehiculeMatricule = vehicule != null && vehicule['matricule'] != null ? vehicule['matricule'] : 'default_matricule';
            final vehiculeNumeroSerie = vehicule != null ? vehicule['numero_serie'] : '';
            final vehiculeCapacite = vehicule != null ? vehicule['capacite'] : '';
            final vehiculeMarque = vehicule != null ? vehicule['marque'] : '';
            final typeVehicule = type != null ? type['type'] : '';

            final societe = intervention['contrat']['societe'];
            final societeName = societe != null && societe['societe'] != null ? societe['societe'] : 'default_societe';
            final societeEmail = societe != null ? societe['email'] : 'default_societe';
            final societeResponsable = societe != null ? societe['responsable'] : 'default_societe';

            if (status == 'Terminer') {
              totalTerminerInterventions++;
              interventionsTerminer.add({
                'id': interventionId,
                'contrat_id': contratId,
                'date_intervention': dateIntervention,
                'date_validation': dateValidation,
                'status': status,
                'matricule': vehiculeMatricule,
                'image': vehiculeImage,
                'societe': societeName,
              });
              interventionsEmpty = false;
            }

            String imagePath;
            if (vehiculeImage != null && vehiculeImage.isNotEmpty) {
              final imageUrl = 'https://liya.is-tech.app/storage/$vehiculeImage';
              final imageName = vehiculeImage.split('/').last;
              imagePath = await _downloadImage(imageUrl, imageName);
            } else {
              imagePath = '';
            }

            // Save the intervention data to the local database
            saveIntervention(interventionId, contratId, dateIntervention, dateValidation, status, vehiculeMatricule, imagePath, societeName,
                vehiculeNumeroSerie, vehiculeCapacite, typeVehicule, vehiculeMarque, societeResponsable, societeEmail);
          }
          printIntervention();
        } else {
          print('Failed to fetch interventions. Status code: ${response.statusCode}');
        }
      }

      setState(() {
        interventionTerminer = totalTerminerInterventions;
        interventionEmpty = interventionsEmpty;
        indicator = false;
      });
    }
  }

  //to download the path of the image for offline use
  Future<String> _downloadImage(String imageUrl, String imageName) async {
    final response = await http.get(Uri.parse(imageUrl));
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/$imageName';
    final File imageFile = File(imagePath);
    await imageFile.writeAsBytes(response.bodyBytes);
    return imagePath;
  }

  Future<void> refreshData() async {
    await fetchInterventions();
    setState(() {
      // Update the UI after fetching new data
    });
    _refreshController.refreshCompleted();
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
            title: Text("Rapports", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 23)),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
          body: SmartRefresher(
            controller: _refreshController,
            enablePullDown: true,
            header: WaterDropMaterialHeader(),
            onRefresh: refreshData,
            child: Column(
              // ignore: prefer_const_literals_to_create_immutables
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Padding(
                  padding: EdgeInsets.only(left: 20, top: 30),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Listes des rapports :',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
                indicator
                    ? Center(
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height / 2,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SpinKitThreeBounce(
                              size: 40,
                              color: Color(0xFFf96006),
                            ),
                          ),
                        ),
                      )
                    : interventionTerminer == 0
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width / 1.5,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text(
                                        "Il n'y a pas encore des rapports",
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        "appuyez sur '+' pour ajouter un rapport",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : SizedBox(height: 20),
                StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                  return Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: interventionsTerminer.reversed.fold<List<Widget>>(
                          [],
                          (List<Widget> containers, intervention) {
                            final societeName = intervention['societe'];
                            final vehiculeMatricule = intervention['matricule'];
                            final vehiculeImage = intervention['image'];
                            final dateValidation = intervention['date_validation'];
                            final interventionContainer = Padding(
                              padding: const EdgeInsets.only(top: 15),
                              child: Center(
                                child: Container(
                                  constraints: BoxConstraints(
                                    minHeight: 110,
                                    maxHeight: double.infinity,
                                  ),
                                  width: MediaQuery.of(context).size.width / 1.05,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (vehiculeImage != null && vehiculeImage.isNotEmpty)
                                        connexionCheck
                                            ? Padding(
                                                padding: const EdgeInsets.only(left: 8.0, top: 10),
                                                child: Container(
                                                  height: 90,
                                                  width: MediaQuery.of(context).size.width * 0.35,
                                                  decoration: BoxDecoration(
                                                    image: DecorationImage(image: FileImage(File(vehiculeImage)), fit: BoxFit.cover),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ))
                                            : Padding(
                                                padding: const EdgeInsets.only(left: 8.0, top: 10),
                                                child: Container(
                                                  height: 90,
                                                  width: MediaQuery.of(context).size.width * 0.35,
                                                  decoration: BoxDecoration(
                                                    image: DecorationImage(
                                                      image: NetworkImage(
                                                        "https://liya.is-tech.app/storage/$vehiculeImage",
                                                      ),
                                                      fit: BoxFit.cover,
                                                    ),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                              ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(left: 10.0, top: 15),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: RichText(
                                                text: TextSpan(
                                                    text: 'société: ',
                                                    style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 49, 49, 49)),
                                                    children: [
                                                      TextSpan(
                                                          text: societeName,
                                                          style: TextStyle(
                                                              fontSize: MediaQuery.of(context).size.width * 0.04,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.black))
                                                    ]),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 10.0, top: 5),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: RichText(
                                                  text: TextSpan(
                                                      text: 'matricule: ',
                                                      style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 49, 49, 49)),
                                                      children: [
                                                    TextSpan(
                                                        text: vehiculeMatricule,
                                                        style: TextStyle(
                                                            fontSize: MediaQuery.of(context).size.width * 0.03, color: Colors.black))
                                                  ])),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.only(left: 10, top: 5),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: RichText(
                                                  text: TextSpan(
                                                      text: 'date: ',
                                                      style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 49, 49, 49)),
                                                      children: [
                                                    TextSpan(
                                                        text: dateValidation,
                                                        style: TextStyle(
                                                            fontSize: MediaQuery.of(context).size.width * 0.03, color: Colors.black))
                                                  ])),
                                            ),
                                          )
                                        ],
                                      ),
                                      Spacer(),
                                      IconButton(
                                          onPressed: () async {
                                            int? interventionId = intervention['id'];
                                            // ignore: deprecated_member_use
                                            //await launch('https://liya.is-tech.app/storage/images/1686056256.pdf');

                                            final prefs = await SharedPreferences.getInstance();
                                            String? reportPdfUrl = prefs.getString('reportPdfUrl_$interventionId');
                                            if (reportPdfUrl != null) {
                                              // ignore: deprecated_member_use
                                              await launch(reportPdfUrl);
                                            } else {
                                              print('PDF URL not found for intervention ID: $interventionId');
                                            }
                                          },
                                          icon: Icon(
                                            Icons.visibility,
                                            color: Colors.deepOrange,
                                          ))
                                    ],
                                  ),
                                ),
                              ),
                            );
                            containers.add(interventionContainer);
                            return containers;
                          },
                        ),
                      ),
                    ),
                  );
                }),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20.0, bottom: 10),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: GestureDetector(
                        onTap: () {
                          // checkPermission();
                          Provider.of<Counter>(context, listen: false).increment1();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CalendrierPage(),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.deepOrange,
                          child: Icon(Icons.add, color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void saveIntervention(interventionId, contratId, dateIntervention, dateValidation, status, matricule, vehiculeImage, societeName,
      numeroSerie, capaciteHayon, typeHayon, marqueHayon, nomClient, emailClient) async {
    final sqlDb = SqlDb();
    final imagePath = vehiculeImage != null && vehiculeImage.isNotEmpty ? vehiculeImage : '';
    await sqlDb.addInterventions(interventionId, contratId, dateIntervention, dateValidation ?? '', status, matricule ?? '', imagePath,
        societeName ?? '', numeroSerie ?? '', capaciteHayon ?? '', typeHayon ?? '', marqueHayon ?? '', nomClient ?? '', emailClient ?? '');
  }

  void printIntervention() async {
    final sqlDb = SqlDb();
    final interventions = await sqlDb.getData('interventions');
    for (final intervention in interventions) {
      print('id : ${intervention['id']}, contrat_id : ${intervention['contrat_id']}, matricule: ${intervention['matricule']}');
      print(
          'date_intervention : ${intervention['date_intervention']}, date_validation: ${intervention['date_validation']}, status : ${intervention['status']}');
      print('vehicule_image: ${intervention['vehicule_image']}, societe_name: ${intervention['societe_name']}');
    }
  }

  void clean(table) async {
    final sqlDb = SqlDb();
    await sqlDb.cleanTable(table);
    print('the table had been cleaned');
  }
}
