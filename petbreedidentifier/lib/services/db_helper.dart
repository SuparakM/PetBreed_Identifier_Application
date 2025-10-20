import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  /// กล่องเก็บฐานข้อมูล: ประกาศตัวแปรส่วนตัว (_) ชื่อ _database 
  /// สำหรับเก็บ "การเชื่อมต่อ" ฐานข้อมูล. static แปลว่าใช้ร่วมกันทั้งแอปฯ
  static Database? _database;

  /// ฟังก์ชันสำหรับเชื่อมต่อฐานข้อมูล
  static Future<Database> get database async {
    /// ถ้ามีการเชื่อมต่อฐานข้อมูลอยู่แล้ว ให้คืนค่าการเชื่อมต่อเดิม
    if (_database != null) return _database!;
    /// ถ้ายังไม่มีการเชื่อมต่อฐานข้อมูล ให้สร้างการเชื่อมต่อใหม่
    _database = await _initDB("pets_history.db");
    // คืนค่าการเชื่อมต่อฐานข้อมูล
    return _database!;
  }

  /// ฟังก์ชันสำหรับสร้างฐานข้อมูล
  static Future<Database> _initDB(String filePath) async {
    /// หาตำแหน่งที่เก็บฐานข้อมูล
    final dbPath = await getDatabasesPath();
    /// รวมตำแหน่งที่เก็บฐานข้อมูลกับชื่อไฟล์ฐานข้อมูล
    final path = join(dbPath, filePath);

    /// เปิดฐานข้อมูล (ถ้ายังไม่มีฐานข้อมูล จะสร้างฐานข้อมูลใหม่)
    return await openDatabase(
      path, /// ตำแหน่งที่เก็บฐานข้อมูล
      version: 1, /// เวอร์ชันของฐานข้อมูล
      onCreate: _createDB, /// ฟังก์ชันสำหรับสร้างตารางในฐานข้อมูล
    );
  }

  /// ฟังก์ชันสำหรับสร้างตารางในฐานข้อมูล
  static Future _createDB(Database db, int version) async {
    /// สร้างตาราง pets_history
    await db.execute('''
      CREATE TABLE pets_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        datetime TEXT,
        originalImage TEXT,
        boxedImage TEXT,
        breeds TEXT,
        ages TEXT,
        breedDetails TEXT,
        ageTips TEXT,
        boxes TEXT
      )
    ''');
  }
  
  /// บันทึกข้อมูล (Insert): สำหรับเพิ่มรายการประวัติใหม่เข้าไปในตาราง
  static Future<int> insertHistory(Map<String, dynamic> data) async {
    final db = await database; /// เชื่อมต่อฐานข้อมูล

    /// แทรกข้อมูลลงในตาราง pets_history
    return await db.insert('pets_history', data); 
  }

  /// ดึงข้อมูล (Query): สำหรับดึงรายการประวัติทั้งหมดออกมา
  static Future<List<Map<String, dynamic>>> getAllHistory() async {
    final db = await database; /// เชื่อมต่อฐานข้อมูล

    /// ดึงข้อมูลทั้งหมดจากตาราง pets_history เรียงตามวันที่ล่าสุด
    return await db.query('pets_history', orderBy: "datetime DESC"); 
  }

  /// ลบข้อมูล (Delete): สำหรับลบรายการประวัติเฉพาะตัว
  static Future<int> deleteHistory(int id) async {
    final db = await database; /// เชื่อมต่อฐานข้อมูล

    /// ลบข้อมูลจากตาราง pets_history ที่มี id ตรงกับที่ระบุ
    return await db.delete('pets_history', where: 'id = ?', whereArgs: [id]);
  }

  /// ลบข้อมูลทั้งหมด: สำหรับล้างประวัติทั้งหมด
  static Future<int> clearHistory() async {
    final db = await database; /// เชื่อมต่อฐานข้อมูล

    /// ลบข้อมูลทั้งหมดจากตาราง pets_history
    return await db.delete('pets_history');
  }
}