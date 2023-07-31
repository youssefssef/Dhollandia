// ignore_for_file: prefer_final_fields, unused_element

import 'package:flutter/material.dart';

class Counter extends ChangeNotifier {
  int _count = 0;
  int _reportCount = 0;
  int? _interventionId;
  String _lat = '';
  String _long = '';
  String _date = '';

  int get count => _count;
  int get reportCount => _reportCount;
  int? get interventionId => _interventionId;
  String get latitude => _lat;
  String get longitude => _long;
  String get date => _date;

  void increment() {
    _count++;
    notifyListeners();
  }

  void increment1() {
    _reportCount++;
    notifyListeners();
  }

  void setInterventionId(int id) {
    _interventionId = id;
    notifyListeners();
  }

  void setLatitude(String lat) {
    _lat = lat;
    notifyListeners();
  }

  void setLongitude(String long) {
    _long = long;
    notifyListeners();
  }

  void setIntervnetionDate(String date) {
    _date = date;
    notifyListeners();
  }
}
