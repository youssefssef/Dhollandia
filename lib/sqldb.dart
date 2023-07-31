// ignore_for_file: avoid_print, unused_element

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SqlDb {
  static Database? _db;

  Future<Database?> get db async {
    if (_db == null) {
      _db = await initialDb();
      return _db;
    } else {
      return _db;
    }
  }

  Future<Database> initialDb() async {
    String databasepath = await getDatabasesPath();
    String path = join(databasepath, 'local.db');
    Database mydb = await openDatabase(path, version: 6, onCreate: _onCreate, onUpgrade: _onUpgrade);
    return mydb;
  }

  _onUpgrade(Database db, int oldversion, int newversion) {
    print("onUpgrade=========================");
  }

  _onCreate(Database db, int version) async {
    await db.execute(''' 
    CREATE TABLE "interventions" (
      "id" INTEGER NOT NULL ,
      "contrat_id" INTEGER NOT NULL,
      "date_intervention" TEXT,
      "date_validation" TEXT,
      "status" TEXT,
      "matricule" TEXT,
      "vehicule_image" TEXT,
      "societe_name" TEXT,
      "numero_serie" TEXT,
      "capacite_hayon" INTEGER,
      "type_hayon" TEXT,
      "marque_hayon" TEXT,
      "nom_client" TEXT,
      "email_client" TEXT
    )
    ''');
    await db.execute(''' 
    CREATE TABLE "exams" (
      "examen_id" INTEGER NOT NULL,
      "exam_name" TEXT,
      "questions" TEXT,
      "icon" TEXT
    )
    ''');
    await db.execute(''' 
    CREATE TABLE "reports" (
      "intervention_id" INTEGER NOT NULL,
      "lat" TEXT,
      "lng" TEXT,
      "answers" TEXT,
      "time" TEXT 
    )
    ''');
    await db.execute(''' 
    CREATE TABLE "numbreinterventions" (
      "totale_intervention" INTEGER,
      "intervention_terminer" INTEGER,
      "intervention_encours" INTEGER
    )
    ''');

    print("Create database and table");
  }

  //to  get data from table
  Future<List<Map<String, dynamic>>> getData(table) async {
    final db = await this.db;
    return db!.query(table);
  }

  Future<List<Map<String, dynamic>>?> getRowData(table, int id) async {
    final db = await this.db;
    final List<Map<String, dynamic>> result = await db!.query(table, where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result : null;
  }

  //to save the data in interventions table
  Future<void> addInterventions(
      int interventionId,
      int contratId,
      String dateIntervention,
      String dateValidation,
      String status,
      String matricule,
      String vehiculeImage,
      String societeName,
      String numeroSerie,
      int capaciteHayon,
      String typeHayon,
      String marqueHayon,
      String nomClient,
      String emailClient) async {
    final db = await this.db;
    await db!.insert('interventions', {
      'id': interventionId,
      'contrat_id': contratId,
      'date_intervention': dateIntervention,
      'date_validation': dateValidation,
      'status': status,
      'matricule': matricule,
      'vehicule_image': vehiculeImage,
      'societe_name': societeName,
      'numero_serie': numeroSerie,
      'capacite_hayon': capaciteHayon,
      'type_hayon': typeHayon,
      'marque_hayon': marqueHayon,
      'nom_client': nomClient,
      'email_client': emailClient
    });
  }

  //to save the data in interventions table
  Future<void> addExam(int examenId, String examName, String questions, String icon) async {
    final db = await this.db;
    await db!.insert('exams', {'examen_id': examenId, 'exam_name': examName, 'questions': questions, 'icon': icon});
  }

  //to save the data in interventions table
  Future<void> addReport(int id, String latitude, String longitude, String answer, String date) async {
    final db = await this.db;
    await db!.insert('reports', {'intervention_id': id, 'lat': latitude, 'lng': longitude, 'answers': answer, 'time': date});
  }

  //to save date to the table numberinterventions
  Future<void> addTotaleInterventions(int totalInterventions, int interventionTerminer, int interventionEncours) async {
    final db = await this.db;
    await db!.insert('numbreinterventions', {
      'totale_intervention': totalInterventions,
      'intervention_terminer': interventionTerminer,
      'intervention_encours': interventionEncours
    });
  }

  Future<bool> delete(table, String row) async {
    final db = await this.db;
    final rowsAffected = await db!.delete(
      table,
      where: 'row = ?',
      whereArgs: [row],
    );
    return rowsAffected > 0;
  }

  Future<bool> isTableEmpty(table) async {
    final db = await this.db;
    final result = await db!.rawQuery('SELECT COUNT(*) FROM $table');
    final count = Sqflite.firstIntValue(result);
    return count == 0;
  }

  Future<List<int>> getReportIds() async {
    final db = await this.db;
    final result = await db!.rawQuery('SELECT DISTINCT report_id FROM answers');
    return List.generate(result.length, (i) => result[i]['report_id'] as int);
  }

  Future<void> cleanTable(table) async {
    final db = await this.db;
    await db!.delete(table);
  }

  Future<void> updateTable(String table, Map<String, dynamic> values) async {
    final db = await this.db;
    await db!.update(table, values);
  }
}
