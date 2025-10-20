class Pet { /// โมเดลสำหรับข้อมูลสัตว์เลี้ยง
  final String name; /// ชื่อสายพันธุ์
  final String imageAsset; /// ที่อยู่ภาพ
  final String history; /// ประวัติ
  final String personality; /// อุปนิสัย
  final String lifespan; /// อายุขัยเฉลี่ย
  final List<String> careTips; /// สิ่งที่ต้องรู้ก่อนเลี้ยง
  final String animalType; /// ประเภทสัตว์ (เช่น สุนัข, แมว)

  Pet({ /// constructor
    required this.name,
    required this.imageAsset,
    required this.history,
    required this.personality,
    required this.lifespan,
    required this.careTips,
    required this.animalType,
  });

  /// การสร้างวัตถุจากข้อมูลภายนอก
  /// สำหรับสร้างจาก JSON ของ assets หรือ backend
  factory Pet.fromJson(Map<String, dynamic> json, {String? animalType}) {
    return Pet( 
      name: json['ชื่อสายพันธุ์'] ?? json['label'] ?? 'ไม่ระบุ',
      imageAsset: json['image_asset'] ?? '',
      history: json['ประวัติ'] ?? '',
      personality: json['อุปนิสัย'] ?? '',
      lifespan: json['อายุขัยเฉลี่ย'] ?? '',
      careTips: List<String>.from(json['สิ่งที่ต้องรู้ก่อนเลี้ยง'] ?? []), // แปลงเป็นรายการข้อความ List<String>
      animalType: animalType ?? json['ประเภทสัตว์'] ?? 'ไม่ระบุ',
    );
  }
  /// ผลลัพธ์ของ Pet.fromJson: มันจะแปลงชุดข้อมูลดิบ (เช่น ที่มาในรูปแบบ JSON) ให้กลายเป็นวัตถุ Pet ที่ใช้งานได้จริงในโปรแกรม

  /// การแปลงวัตถุกลับไปเป็นข้อมูลสำหรับบันทึก
  // สำหรับบันทึกลง SQLite
  Map<String, dynamic> toJsonMap() {
    return { /// key-value pairs
      'name': name,
      'imageAsset': imageAsset,
      'history': history,
      'personality': personality,
      'lifespan': lifespan,
      'careTips': careTips, // เก็บเป็น array
      'animalType': animalType,
    };
  }
  /// ผลลัพธ์ของ toJsonMap: มันจะแปลงวัตถุ Pet ที่เราใช้งานอยู่ ให้กลายเป็นชุดข้อมูลที่พร้อมจะบันทึกลงในฐานข้อมูลถาวร เพื่อให้เรียกกลับมาใช้ใหม่ได้ในภายหลัง
}