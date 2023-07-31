// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, non_constant_identifier_names, unused_local_variable, unused_label, prefer_const_literals_to_create_immutables, unnecessary_string_interpolations, prefer_const_declarations, prefer_final_fields

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dhollandia/addRapport.dart';
import 'package:dhollandia/calendrier.dart';
import 'package:dhollandia/sqldb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_zoom_drawer/config.dart';
import 'package:flutter_zoom_drawer/flutter_zoom_drawer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;

import 'menuPage.dart';
import 'widget/notifier.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ZoomDrawerController zoomDrawerController = ZoomDrawerController();
  int interventionCount = 0;
  int selectedYear = DateTime.now().year;
  int interventionTerminer = 0;
  int intervnetionEncour = 0;
  bool indicator = true;

  @override
  initState() {
    fetchTotalInterventions();
    super.initState();
  }

  Future<void> fetchTotalInterventions() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final int startYear = selectedYear;
    final int endYear = selectedYear + 4;
    int totalInterventions = 0;
    int totalTerminerInterventions = 0;
    int totalEncoursInterventions = 0;

    final ConnectivityResult connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult != ConnectivityResult.none) {
      // Internet connection available

      for (int year = startYear; year <= endYear; year++) {
        final response = await http.get(
          Uri.parse('https://liya.is-tech.app/api/Intervention/$year'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final List<Map<String, dynamic>> interventions = List<Map<String, dynamic>>.from(data);

          totalInterventions += interventions.length;
          print('Total Interventions in $year: ${interventions.length}');

          for (final intervention in interventions) {
            final status = intervention['status'] != null ? intervention['status']['status'] : '';

            if (status == 'Terminer') {
              totalTerminerInterventions++;
            } else if (status == 'Encours') {
              totalEncoursInterventions++;
            }
          }
        } else {
          print('Failed to fetch interventions. Status code: ${response.statusCode}');
        }
      }
      setState(() {
        indicator = false;
      });
      clean('numbreinterventions');

      // Save the fetched data to the "numbreinterventions" table
      final sqlDb = SqlDb();
      await sqlDb.addTotaleInterventions(totalInterventions, totalTerminerInterventions, totalEncoursInterventions);
    } else {
      // No internet connection, fetch data from local database
      final sqlDb = SqlDb();
      final totals = await sqlDb.getData('numbreinterventions');
      for (final total in totals) {
        totalInterventions = total['totale_intervention'];
        totalTerminerInterventions = total['intervention_terminer'];
        totalEncoursInterventions = total['intervention_encours'];
      }
      setState(() {
        indicator = false;
      });
    }

    setState(() {
      interventionCount = totalInterventions;
      interventionTerminer = totalTerminerInterventions;
      intervnetionEncour = totalEncoursInterventions;
    });

    print('Total Interventions: $interventionCount');
    print('Total Terminer Interventions: $interventionTerminer');
    print('Total Encours Interventions: $intervnetionEncour');
    printInterventions();
  }

  @override
  Widget build(BuildContext context) {
    int count = Provider.of<Counter>(context, listen: false).count;
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
          backgroundColor: Colors.grey[300],
          appBar: AppBar(
            backgroundColor: Colors.orangeAccent,
            leading: IconButton(
              onPressed: () {
                zoomDrawerController.toggle!();
              },
              icon: Icon(
                Icons.menu,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
            title: Text("DHOLLANDIA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 23)),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 30),
                      child: Container(
                        height: 100,
                        width: MediaQuery.of(context).size.width / 2.3,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.white),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 10.0, top: 15),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width * 0.3,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '$interventionCount',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Spacer(),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0, top: 5),
                                  child: CircleAvatar(
                                    backgroundColor: Colors.orangeAccent,
                                    radius: 15,
                                    child: Icon(
                                      Icons.article,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 15.0, top: 25),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Interventions',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 30),
                      child: GestureDetector(
                        onTap: () {
                          //clean();

                          // ignore: use_build_context_synchronously
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddRepport(),
                            ),
                          );
                        },
                        child: Container(
                          height: 100,
                          width: MediaQuery.of(context).size.width / 2.3,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.white),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 10.0, top: 15),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: SizedBox(
                                        width: MediaQuery.of(context).size.width / 3.5,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '$interventionTerminer',
                                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Spacer(),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0, top: 5),
                                    child: CircleAvatar(
                                      backgroundColor: Colors.blueAccent,
                                      radius: 15,
                                      child: Icon(
                                        Icons.analytics,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 15.0, top: 25),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Rapports',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 50),
                Center(
                  child: Consumer<Counter>(builder: (context, counter, child) {
                    return InterventionChart(
                      interventionCount: intervnetionEncour,
                      completedCount: interventionTerminer,
                    );
                  }),
                ),
                SizedBox(height: 40),
                indicator
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: SpinKitThreeBounce(
                            size: 40,
                            color: Color(0xFFf96006),
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CalendrierPage(),
                            ),
                          );
                        },
                        child: Text('Ajouter rapport'))
              ],
            ),
          ),
        ),
      ),
    );
  }

  void saveTotaleIntervention(totalInterventions, interventionTerminer, interventionEncours) async {
    final sqlDb = SqlDb();
    await sqlDb.addTotaleInterventions(totalInterventions, interventionTerminer, interventionEncours);
  }

  void printInterventions() async {
    final sqlDb = SqlDb();
    final totals = await sqlDb.getData('numbreinterventions');
    for (final total in totals) {
      print(
          'total_intervention : ${total['totale_intervention']}, intervention_terminer : ${total['intervention_terminer']}, intervention_encours : ${total['intervention_encours']}');
    }
  }

  //to clean the sqflite table
  void clean(table) async {
    final sqlDb = SqlDb();
    await sqlDb.cleanTable(table);
    print('the table had been cleaned');
  }

  Future<bool> TableCheck(table) async {
    final sqlDb = SqlDb();
    return await sqlDb.isTableEmpty(table);
  }
}

//for seconde chart of interventions
class InterventionData {
  final String status;
  final int count;

  InterventionData(this.status, this.count);
}

class InterventionChart extends StatelessWidget {
  final int interventionCount;
  final int completedCount;
  final List<Color> colors = [
    Colors.blue,
    Colors.orange,
  ];

  InterventionChart({Key? key, required this.interventionCount, required this.completedCount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<InterventionData> data = [
      InterventionData('Effectuées', completedCount),
      InterventionData('En attente', interventionCount),
    ];

    return SfCartesianChart(
      title: ChartTitle(text: 'Interventions statistiques effectuées/en attente ', textStyle: TextStyle(fontWeight: FontWeight.bold)),
      primaryXAxis: CategoryAxis(
        edgeLabelPlacement: EdgeLabelPlacement.shift,
      ),
      series: <ChartSeries>[
        ColumnSeries<InterventionData, String>(
          dataSource: data,
          xValueMapper: (InterventionData intervention, _) => intervention.status,
          yValueMapper: (InterventionData intervention, _) => intervention.count,
          dataLabelSettings: DataLabelSettings(isVisible: true),
          pointColorMapper: (InterventionData intervention, int index) => colors[index % colors.length],
        ),
      ],
    );
  }
}
