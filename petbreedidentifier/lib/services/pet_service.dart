import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/pet_model.dart';

class PetService {
  /// โหลดข้อมูลสัตว์เลี้ยงจากไฟล์ JSON ใน assets
  static Future<Map<String, List<Pet>>> loadPetsData() async { /// คืนค่า map ที่มี key เป็น 'dogs' และ 'cats'
    /// โหลดไฟล์ JSON
    final String jsonString = await rootBundle.loadString('assets/data/pets_data.json');
    /// แปลง JSON เป็น Map
    final Map<String, dynamic> data = jsonDecode(jsonString);
    
    /// แปลงข้อมูลเป็น List<Pet> สำหรับสุนัขและแมว
    return {
      /// key 'dogs' และ 'cats' จะเก็บ List<Pet>
      'dogs': (data['สุนัข'] as List)
          /// แปลงแต่ละ element ใน List เป็น Pet object โดยใช้ fromJson constructor และระบุ animalType เป็น 'สุนัข' หรือ 'แมว'
          .map((e) => Pet.fromJson(Map<String, dynamic>.from(e), animalType: 'สุนัข'))
          .toList(), /// รวบรวมวัตถุ Pet ทั้งหมดกลับมาเป็นรายการ List<Pet>
      'cats': (data['แมว'] as List)
          .map((e) => Pet.fromJson(Map<String, dynamic>.from(e), animalType: 'แมว'))
          .toList(),
    };
  }

  /// คืนค่า list ของสายพันธุ์ทั้งหมด
  static Future<List<Pet>> getAllBreeds() async { /// คืนค่ารายการสายพันธุ์ทั้งหมด
    final petsData = await loadPetsData(); /// โหลดข้อมูลสัตว์เลี้ยง

    /// ... เป็นการกระจายรายการ (spread operator) เพื่อรวมสอง list เข้าด้วยกัน
    return [...petsData['dogs']!, ...petsData['cats']!];
  }

  /// หา Pet จากชื่อสายพันธุ์
  static Future<Pet?> getBreedByName(String name) async { /// คืนค่า Pet object หรือ null ถ้าไม่เจอ
    final allBreeds = await getAllBreeds(); /// โหลดรายการสายพันธุ์ทั้งหมด
    try { 
      /// หา Pet ที่มีชื่อสายพันธุ์ตรงกับ name
      return allBreeds.firstWhere((breed) => breed.name == name); 
    } catch (e) {
      return null; // ถ้าไม่เจอชื่อ
    }
  }
}