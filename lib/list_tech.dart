// ignore_for_file: sized_box_for_whitespace, prefer_const_constructors, prefer_const_literals_to_create_immutables, unused_element, unnecessary_null_comparison, unused_field, prefer_final_fields, unused_local_variable, deprecated_member_use, await_only_futures, use_build_context_synchronously

import 'dart:async';
import 'package:dhollandia/Exams.dart';
import 'package:dhollandia/Home_page.dart';
import 'package:dhollandia/sqldb.dart';
import 'package:dhollandia/widget/notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';

class ListTech extends StatefulWidget {
  const ListTech({super.key});

  @override
  State<ListTech> createState() => _ListTechState();
}

class _ListTechState extends State<ListTech> {
  String _locationText = '';
  late String _address;
  final List<Map<String, dynamic>> interventionDetails = [];
  bool loading = true;
  bool positionLoading = true;

  String? _currentAddress;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentPosition();
    fetchDateFromTable();
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Location services are disabled. Please enable the services')));
      return false;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }
    return true;
  }

  // to get latitude et longitude
  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) return;
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((Position position) {
      setState(
        () => _currentPosition = position,
      );
      setState(() {
        positionLoading = false;
      });
      _getAddressFromLatLng(_currentPosition!);
    }).catchError((e) {
      debugPrint(e);
    });
  }

  //to get the adress froom the latitude and longitude
  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
      Placemark place = placemarks[0];
      setState(() {
        _currentAddress = '${place.street}, ${place.subLocality}, ${place.subAdministrativeArea}, ${place.postalCode}';
      });
    } catch (e) {
      debugPrint(e.toString());
      // Handle the error here
    }
  }

  TextEditingController nSerieController = TextEditingController();
  TextEditingController lmmatriculationController = TextEditingController();
  TextEditingController capacitHayonController = TextEditingController();
  TextEditingController typeHayonController = TextEditingController();
  TextEditingController marqueHayonController = TextEditingController();
  TextEditingController clientController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController dateHeurController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orangeAccent,
        automaticallyImplyLeading: false,
        leading: IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
            },
            icon: Icon(
              Icons.arrow_back,
              color: Colors.white,
            )),
        centerTitle: true,
        title: Text(
          "DHOLLANDIA",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 23),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: ListView(
          children: [
            SizedBox(height: 15),
            Visibility(
              visible: loading,
              child: Center(
                child: SpinKitWave(
                  size: 35,
                  color: Color(0xFFf96006),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: TextFormField(
                controller: TextEditingController(text: loading ? ' Numéro de série ' : interventionDetails[0]['numero_serie']),
                readOnly: true,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Numéro de série',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
              child: TextFormField(
                controller: TextEditingController(text: loading ? '' : interventionDetails[0]['matricule']),
                readOnly: true,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Immatriculation',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
              child: TextFormField(
                controller: TextEditingController(text: loading ? '' : '${interventionDetails[0]['capacite_hayon']}'),
                readOnly: true,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Capacité du hayon',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
              child: TextFormField(
                controller: TextEditingController(text: loading ? '' : interventionDetails[0]['type_hayon']),
                readOnly: true,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'le type de hayon',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
              child: TextFormField(
                controller: TextEditingController(text: loading ? '' : interventionDetails[0]['marque_hayon']),
                readOnly: true,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'la marque de hayon',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
              child: TextFormField(
                controller: TextEditingController(text: loading ? '' : interventionDetails[0]['nom_client']),
                readOnly: true,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Nom du client',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
              child: TextFormField(
                controller: TextEditingController(text: loading ? '' : interventionDetails[0]['email_client']),
                readOnly: true,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Email du client',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
              child: TextFormField(
                initialValue: DateFormat('yyyy-MM-dd -- KK:mm:ss').format(DateTime.now()),
                style: TextStyle(color: Colors.grey[800]),
                readOnly: true,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Date et Heure',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
              child: TextFormField(
                controller:
                    TextEditingController(text: 'X: ${_currentPosition?.latitude ?? ""} -- Y: ${_currentPosition?.longitude ?? ""}'),
                enabled: false,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Position',
                ),
              ),
            ),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
                child: positionLoading
                    ? Visibility(
                        visible: positionLoading,
                        child: Center(
                          child: SpinKitWave(
                            size: 35,
                            color: Color(0xFFf96006),
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () {
                          Provider.of<Counter>(context, listen: false).setLatitude(_currentPosition!.latitude.toString());
                          Provider.of<Counter>(context, listen: false).setLongitude(_currentPosition!.longitude.toString());

                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ExamsPage()));
                        },
                        child: Text(
                          'Suivant',
                          style: TextStyle(fontSize: 16),
                        ),
                      )),
          ],
        ),
      ),
    );
  }

  void fetchDateFromTable() async {
    final sqlDb = SqlDb();
    int? interventionId = Provider.of<Counter>(context, listen: false).interventionId;

    final List<Map<String, dynamic>>? interventions = await sqlDb.getRowData('interventions', interventionId!);
    interventionDetails.clear();
    for (final intervention in interventions!) {
      final vehiculeMatricule = intervention['matricule'] ?? '';
      final numeroSerie = intervention['numero_serie'] ?? '';
      final capaciteHayon = intervention['capacite_hayon'] ?? '';
      final typeHayon = intervention['type_hayon'] ?? '';
      final marqueHayon = intervention['marque_hayon'];
      final nomClient = intervention['nom_client'] ?? '';
      final emailClient = intervention['email_client'] ?? '';

      interventionDetails.add({
        'numero_serie': numeroSerie,
        'matricule': vehiculeMatricule,
        'capacite_hayon': capaciteHayon,
        'type_hayon': typeHayon,
        'marque_hayon': marqueHayon,
        'nom_client': nomClient,
        'email_client': emailClient,
      });
    }
    print(interventionDetails);
    setState(() {
      loading = false;
    });
  }
}
