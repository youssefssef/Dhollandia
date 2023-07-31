// ignore_for_file: prefer_const_constructors, prefer_final_fields, avoid_unnecessary_containers, unused_field, sized_box_for_whitespace

import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dhollandia/list_tech.dart';
import 'package:dhollandia/sqldb.dart';
import 'package:dhollandia/widget/notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_zoom_drawer/config.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'menuPage.dart';
import 'package:http/http.dart' as http;

class CalendrierPage extends StatefulWidget {
  const CalendrierPage({super.key});

  @override
  State<CalendrierPage> createState() => _CalendrierPageState();
}

class _CalendrierPageState extends State<CalendrierPage> {
  ZoomDrawerController zoomDrawerController = ZoomDrawerController();
  List<Map<String, dynamic>> interventions = [];
  List<Map<String, dynamic>> interventionList = [];
  List<int> interventionDates = [];
  List<Map<String, dynamic>> _interventionList = [];
  int selectedYear = DateTime.now().year;
  List<int> createdContainers = [];
  bool _isLoading = true;

  final List<String> months = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Aout',
    'September',
    'October',
    'November',
    'Décember'
  ];

  //int selectedMonthIndex = DateTime.now().month - 1;
  int selectedMonthIndex = -1;
  bool connexionCheck = false;

  @override
  initState() {
    fetchInterventions();
    super.initState();
  }

  //get data for interventions and contrat
  Future<void> fetchInterventions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      // No internet connection, fetch data from local database
      final sqlDb = SqlDb();
      final List<Map<String, dynamic>> interventions = await sqlDb.getData('interventions');
      setState(() {
        connexionCheck = true;
      });

      final List<Map<String, dynamic>> processedInterventions = [];

      for (final intervention in interventions) {
        final contratId = intervention['contrat_id'];
        final dateIntervention = intervention['date_intervention'];
        final interventionId = intervention['id'];
        final dateValidation = intervention['date_validation'];
        final status = intervention['status'];
        final vehiculeImage = intervention['vehicule_image'] ?? '';
        final vehiculeMatricule = intervention['matricule'] ?? '';
        final societeName = intervention['societe_name'];

        final month = DateTime.parse(dateIntervention).month;
        final year = DateTime.parse(dateIntervention).year;

        if (year == selectedYear) {
          interventionDates.add(month);
        }

        processedInterventions.add({
          'id': interventionId,
          'contrat_id': contratId,
          'date_intervention': dateIntervention,
          'date_validation': dateValidation,
          'status': status,
          'matricule': vehiculeMatricule,
          'image': vehiculeImage,
          'societe': societeName,
        });
      }
      printIntervention();
      setState(() {
        this.interventions = processedInterventions;
        _isLoading = false;
      });
    } else {
      // Internet connection available, fetch data from API
      final response = await http.get(
        Uri.parse('https://liya.is-tech.app/api/Intervention/$selectedYear'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final interventionList = List<Map<String, dynamic>>.from(data);

        // Clear the interventionDates list before adding new dates
        interventionDates.clear();
        interventions.clear();

        // Clean the table before saving new data
        clean('interventions');

        for (final intervention in interventionList) {
          final contratId = intervention['contrat_id'];
          final dateIntervention = intervention['date_intervention'];
          final interventionId = intervention['id'];
          final dateValidation = intervention['date_validation'];
          final status = intervention['status'] != null ? intervention['status']['status'] : '';

          final vehicule = intervention['contrat']['vehicule'];
          final type = intervention['contrat']['vehicule']['typevehicule'];
          final vehiculeImage = vehicule != null && vehicule.isNotEmpty ? vehicule['image'] : '';
          final vehiculeMatricule = vehicule != null ? vehicule['matricule'] : 'default_matricule';
          final vehiculeNumeroSerie = vehicule != null ? vehicule['numero_serie'] : '';
          final vehiculeCapacite = vehicule != null ? vehicule['capacite'] : '';
          final vehiculeMarque = vehicule != null ? vehicule['marque'] : '';
          final typeVehicule = type != null ? type['type'] : '';

          final societe = intervention['contrat']['societe'];
          final societeName = societe != null ? societe['societe'] : 'default_societe';
          final societeEmail = societe != null ? societe['email'] : 'default_societe';
          final societeResponsable = societe != null ? societe['responsable'] : 'default_societe';

          final month = DateTime.parse(dateIntervention).month;
          final year = DateTime.parse(dateIntervention).year;

          if (year == selectedYear) {
            interventionDates.add(month);
          }

          // Download and save the vehicle image
          String imagePath;
          if (vehiculeImage != null && vehiculeImage.isNotEmpty) {
            final imageUrl = 'https://liya.is-tech.app/storage/$vehiculeImage';
            final imageName = vehiculeImage.split('/').last;
            imagePath = await _downloadImage(imageUrl, imageName);
          } else {
            imagePath = '';
          }

          interventions.add({
            'contrat_id': contratId,
            'date_intervention': dateIntervention,
            'id': interventionId,
            'date_validation': dateValidation,
            'status': status,
            'matricule': vehiculeMatricule,
            'image': vehiculeImage,
            'societe': societeName,
          });

          // Save the intervention data to the local database
          saveIntervention(interventionId, contratId, dateIntervention, dateValidation, status, vehiculeMatricule, imagePath, societeName,
              vehiculeNumeroSerie, vehiculeCapacite, typeVehicule, vehiculeMarque, societeResponsable, societeEmail);
        }
        printIntervention();

        setState(() {
          connexionCheck = false;
          _isLoading = false;
        });
      } else {
        print('Failed to fetch interventions. Status code: ${response.statusCode}');
      }
    }
  }

  Future<String> _downloadImage(String imageUrl, String imageName) async {
    final response = await http.get(Uri.parse(imageUrl));
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = '${directory.path}/$imageName';
    final File imageFile = File(imagePath);
    await imageFile.writeAsBytes(response.bodyBytes);
    return imagePath;
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
            title: Text("Interventions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 23)),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0, top: 20),
                    child: DropdownButton<int>(
                      value: selectedYear,
                      onChanged: (int? newValue) {
                        setState(() {
                          selectedYear = newValue!;
                          _isLoading = true;
                        });
                        fetchInterventions();
                      },
                      items: List<int>.generate(10, (index) => DateTime.now().year + index).map<DropdownMenuItem<int>>((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(value.toString()),
                        );
                      }).toList(),
                    ),
                  ),
                  Spacer(),
                  Visibility(
                    visible: _isLoading,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20, top: 20),
                      child: SpinKitHourGlass(
                        size: 30,
                        color: Color(0xFFf96006),
                      ),
                    ),
                  ),
                ],
              ),
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: constraints.maxWidth > 600 ? 6 : 4,
                              ),
                              itemCount: months.length,
                              itemBuilder: (context, index) {
                                final monthIntervention = index + 1;
                                final interventionsInMonth = interventions.where((intervention) =>
                                    DateTime.parse(intervention['date_intervention']).month == monthIntervention &&
                                    DateTime.parse(intervention['date_intervention']).year == selectedYear);
                                final allTerminer = interventionsInMonth.every((intervention) => intervention['status'] == 'Terminer');
                                final hasEncour = interventionsInMonth.any((intervention) => intervention['status'] == 'Encours');

                                return GestureDetector(
                                  onTap: () {
                                    if (interventionDates.contains(monthIntervention)) {
                                      setState(() {
                                        selectedMonthIndex = index;
                                        createdContainers.clear();
                                      });
                                    } else {
                                      setState(() {
                                        selectedMonthIndex = -1;
                                      });
                                    }
                                  },
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 2.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: interventionDates.contains(monthIntervention)
                                                ? (allTerminer ? Colors.green : (hasEncour ? Colors.deepOrange : Colors.transparent))
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                        padding: EdgeInsets.all(10),
                                        child: FittedBox(
                                          fit: BoxFit.fitWidth,
                                          child: Text(
                                            months[index],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: interventionDates.contains(monthIntervention)
                                                  ? (allTerminer ? Colors.green : (hasEncour ? Colors.deepOrange : Colors.transparent))
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      if (selectedMonthIndex == -1)
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width / 1.4,
                              child: Text(
                                "Il n'y a pas d'intervention ce mois-ci",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 18,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      if (selectedMonthIndex != -1 &&
                          interventions.any((intervention) =>
                              DateTime.parse(intervention['date_intervention']).month == selectedMonthIndex + 1 &&
                              DateTime.parse(intervention['date_intervention']).year == selectedYear))
                        Padding(
                          padding: const EdgeInsets.only(left: 20.0),
                          child: Text(
                            'Listes des interventions :',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      if (selectedMonthIndex != -1 &&
                          interventions.any((intervention) =>
                              DateTime.parse(intervention['date_intervention']).month == selectedMonthIndex + 1 &&
                              DateTime.parse(intervention['date_intervention']).year == selectedYear))
                        Expanded(
                          child: Visibility(
                            visible: selectedMonthIndex != -1,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: interventions.fold<List<Widget>>(
                                  [],
                                  (List<Widget> containers, intervention) {
                                    final dateIntervention = intervention['date_intervention'];
                                    final month = DateTime.parse(dateIntervention).month;
                                    final year = DateTime.parse(dateIntervention).year;

                                    if (month == selectedMonthIndex + 1 && year == selectedYear) {
                                      final contratId = intervention['contrat_id'];
                                      final interventionId = intervention['id'];
                                      final status = intervention['status'];
                                      final societeName = intervention['societe'];
                                      final vehiculeMatricule = intervention['matricule'];
                                      final vehiculeImage = intervention['image'];

                                      // Check if the contrat ID already exists in the createdContainers list
                                      if (!createdContainers.contains(interventionId)) {
                                        containers.add(
                                          Padding(
                                            padding: const EdgeInsets.only(top: 15),
                                            child: Center(
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  minHeight: 120,
                                                  maxHeight: double.infinity,
                                                ),
                                                width: MediaQuery.of(context).size.width / 1.2,
                                                key: ValueKey<String>('contrat_$contratId'),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(15),
                                                  border: Border.all(color: Colors.grey),
                                                ),
                                                child: Expanded(
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      if (vehiculeImage != null && vehiculeImage.isNotEmpty)
                                                        connexionCheck
                                                            ? Padding(
                                                                padding: const EdgeInsets.only(left: 8.0, top: 10),
                                                                child: Container(
                                                                  height: 100,
                                                                  width: MediaQuery.of(context).size.width * 0.4,
                                                                  decoration: BoxDecoration(
                                                                    image: DecorationImage(
                                                                        image: FileImage(File(vehiculeImage)), fit: BoxFit.cover),
                                                                    borderRadius: BorderRadius.circular(10),
                                                                  ),
                                                                ))
                                                            : Padding(
                                                                padding: const EdgeInsets.only(left: 8.0, top: 10),
                                                                child: Container(
                                                                  height: 100,
                                                                  width: MediaQuery.of(context).size.width * 0.4,
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
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Padding(
                                                              padding: const EdgeInsets.only(left: 10.0, top: 15),
                                                              child: RichText(
                                                                text: TextSpan(
                                                                    text: 'société: ',
                                                                    style: TextStyle(fontSize: 13, color: Color.fromARGB(255, 94, 91, 91)),
                                                                    children: [
                                                                      TextSpan(
                                                                          text: societeName,
                                                                          style: TextStyle(
                                                                              fontSize: 15,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Colors.black))
                                                                    ]),
                                                              ),
                                                            ),
                                                            SizedBox(height: 5),
                                                            Padding(
                                                                padding: const EdgeInsets.only(left: 10.0),
                                                                child: RichText(
                                                                    text: TextSpan(
                                                                        text: 'matricule: ',
                                                                        style:
                                                                            TextStyle(fontSize: 13, color: Color.fromARGB(255, 94, 91, 91)),
                                                                        children: [
                                                                      TextSpan(
                                                                          text: vehiculeMatricule,
                                                                          style: TextStyle(fontSize: 14, color: Colors.black))
                                                                    ]))),
                                                            SizedBox(height: 8),
                                                            Padding(
                                                                padding: const EdgeInsets.only(left: 10.0),
                                                                child: RichText(
                                                                  text: TextSpan(
                                                                      text: 'status: ',
                                                                      style:
                                                                          TextStyle(fontSize: 13, color: Color.fromARGB(255, 94, 91, 91)),
                                                                      children: [
                                                                        TextSpan(
                                                                            text: status,
                                                                            style: TextStyle(
                                                                              fontSize: 16,
                                                                              fontWeight: FontWeight.bold,
                                                                              color:
                                                                                  status == 'Terminer' ? Colors.green : Colors.deepOrange,
                                                                            ))
                                                                      ]),
                                                                )),
                                                            Visibility(
                                                              visible: status == 'Encours',
                                                              child: Padding(
                                                                padding: EdgeInsets.only(right: 5, top: 8, bottom: 8),
                                                                child: Align(
                                                                  alignment: Alignment.bottomRight,
                                                                  child: Container(
                                                                    height: 30,
                                                                    width: 70,
                                                                    decoration: BoxDecoration(
                                                                        borderRadius: BorderRadius.circular(10), color: Colors.deepOrange),
                                                                    child: TextButton(
                                                                        onPressed: () {
                                                                          Provider.of<Counter>(context, listen: false)
                                                                              .setInterventionId(interventionId);
                                                                          print(interventionId);
                                                                          Navigator.push(
                                                                            context,
                                                                            MaterialPageRoute(
                                                                              builder: (context) => ListTech(),
                                                                            ),
                                                                          );
                                                                        },
                                                                        child: Text(
                                                                          'suivant',
                                                                          style: TextStyle(color: Colors.white),
                                                                        )),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                        createdContainers.add(interventionId); // Add the intervention ID to the createdContainers list
                                      }
                                    }
                                    return containers;
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  );
                },
              ),
            ],
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
      // print('date_intervention : ${intervention['date_intervention']}, date_validation: ${intervention['date_validation']}, status : ${intervention['status']}');
      //print('vehicule_image: ${intervention['vehicule_image']}, societe_name: ${intervention['societe_name']}');
      print(
          'numero_serie : ${intervention['numero_serie']}, capacite_hayon : ${intervention['capacite_hayon']}, type_hayon : ${intervention['type_hayon']} ');
      print(
          'marque_hayon : ${intervention['marque_hayon']}, nom_client : ${intervention['nom_client']}, email_client: ${intervention['email_client']} ');
    }
  }

  void clean(table) async {
    final sqlDb = SqlDb();
    await sqlDb.cleanTable(table);
    print('the table had been cleaned');
  }
}
