import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'custom_template_model.dart';

class CustomTemplateService {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'docease_templates.db');

    return openDatabase(
      path,
      version: 2, // bumped for migration
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE custom_templates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            headerText TEXT NOT NULL,
            footerText TEXT NOT NULL,
            headerImagePath TEXT NOT NULL,
            footerImagePath TEXT NOT NULL,
            backgroundImagePath TEXT NOT NULL,
            imageMode TEXT NOT NULL DEFAULT 'zones',
            backgroundOpacity REAL NOT NULL DEFAULT 0.9,
            bodyTopMargin REAL NOT NULL DEFAULT 160.0,
            createdAt TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE custom_templates ADD COLUMN backgroundImagePath TEXT NOT NULL DEFAULT ""');
          await db.execute(
              'ALTER TABLE custom_templates ADD COLUMN imageMode TEXT NOT NULL DEFAULT "zones"');
          await db.execute(
              'ALTER TABLE custom_templates ADD COLUMN backgroundOpacity REAL NOT NULL DEFAULT 0.9');
          await db.execute(
              'ALTER TABLE custom_templates ADD COLUMN bodyTopMargin REAL NOT NULL DEFAULT 160.0');
        }
      },
    );
  }

  static Future<int> save(CustomTemplate template) async {
    final db = await database;
    if (template.id != null) {
      await db.update(
        'custom_templates',
        template.toMap(),
        where: 'id = ?',
        whereArgs: [template.id],
      );
      return template.id!;
    }
    return db.insert('custom_templates', template.toMap());
  }

  static Future<List<CustomTemplate>> getAll() async {
    final db = await database;
    final maps = await db.query(
      'custom_templates',
      orderBy: 'createdAt DESC',
    );
    return maps.map(CustomTemplate.fromMap).toList();
  }

  static Future<void> delete(int id) async {
    final db = await database;
    await db.delete(
      'custom_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}