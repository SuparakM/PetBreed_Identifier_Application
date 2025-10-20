import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pet_model.dart';

class BreedDetailScreen extends StatefulWidget {
  final Pet pet;  // รับข้อมูลสายพันธุ์สัตว์เลี้ยง
  const BreedDetailScreen({super.key, required this.pet});

  @override
  State<BreedDetailScreen> createState() => _BreedDetailScreenState();
}

class _BreedDetailScreenState extends State<BreedDetailScreen> {
  Map<String, String> lifeStages = {};  // เก็บข้อมูลคำแนะนำการดูแลแต่ละช่วงวัย

  @override
  void initState() {
    super.initState();
    loadLifeStages(); // โหลดข้อมูลคำแนะนำการดูแลแต่ละช่วงวัยจากไฟล์ JSON
  }

  // โหลดข้อมูลคำแนะนำการดูแลแต่ละช่วงวัยจากไฟล์ JSON
  Future<void> loadLifeStages() async {
    //  โหลดไฟล์ JSON จาก assets
    final jsonString = await rootBundle.loadString('assets/data/lifestage_care.json');
    // แปลงข้อมูล JSON เป็น Map
    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    // ดึงข้อมูลคำแนะนำการดูแลแต่ละช่วงวัยตามประเภทสัตว์เลี้ยง
    final animalLifeStages = jsonMap[widget.pet.animalType]; // เช่น 'สุนัข' หรือ 'แมว'

    // แปลงข้อมูลเป็น Map<String, String> และอัปเดตสถานะ
    if (animalLifeStages != null) {
      setState(() {
        lifeStages = Map<String, String>.from(animalLifeStages);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(  // ใช้ Scaffold เพื่อสร้างโครงสร้างหน้าจอ
      backgroundColor: const Color(0xFFFFA726),
      appBar: AppBar( // AppBar ด้านบนของหน้าจอ
        backgroundColor: const Color(0xFFCE8426),
        title: Text(
          widget.pet.name,
          style: const TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: lifeStages.isEmpty  // แสดงตัวโหลดข้อมูลหากยังไม่มีข้อมูลคำแนะนำการดูแล  
          ? const Center(child: CircularProgressIndicator())  // แสดงตัวโหลดข้อมูล
          : ListView( // ใช้ ListView เพื่อให้หน้าจอสามารถเลื่อนดูข้อมูลได้
              padding: const EdgeInsets.all(16),
              children: [
                _buildImageSection(), // แสดงภาพของสายพันธุ์สัตว์เลี้ยง
                _buildBreedName(),  // แสดงชื่อสายพันธุ์สัตว์เลี้ยง
                _buildInfoExpansionTiles(), // แสดงข้อมูลต่างๆ ในรูปแบบ ExpansionTile
                _buildLifeStageSection(), // แสดงคำแนะนำการดูแลแต่ละช่วงวัย
              ],
            ),
    );
  }

  // สร้างส่วนแสดงภาพของสายพันธุ์สัตว์เลี้ยง
  Widget _buildImageSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 270,
        width: double.infinity,
        color: Colors.grey[200],
        child: Image.asset(
          widget.pet.imageAsset,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // สร้างส่วนแสดงชื่อสายพันธุ์สัตว์เลี้ยง
  Widget _buildBreedName() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        widget.pet.name,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // สร้างส่วนแสดงข้อมูลต่างๆ ในรูปแบบ ExpansionTile
  Widget _buildInfoExpansionTiles() {
    return Column(
      children: [
        _buildExpansionTile(
          title: 'ประวัติ',
          content: widget.pet.history,
          //cardColor: const Color.fromARGB(255, 255, 224, 178),
        ),
        _buildExpansionTile(
          title: 'อุปนิสัย',
          content: widget.pet.personality,
          //cardColor: const Color.fromARGB(255, 255, 224, 178),
        ),
        _buildExpansionTile(
          title: 'อายุขัยเฉลี่ย',
          content: widget.pet.lifespan,
          //cardColor: const Color.fromARGB(255, 255, 224, 178),
        ),
        _buildExpansionTile(
          title: 'สิ่งที่ต้องรู้ก่อนเลี้ยง',
          //cardColor: const Color.fromARGB(255, 255, 224, 178),
          contentWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // สิ่งที่ต้องรู้ก่อนเลี้ยง' ข้อมูลจะแสดงเป็นรายการแบบ มีหัวข้อจุด (•)
            children: widget.pet.careTips.map((tip) => 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ).toList(),
          ),
        ),
      ],
    );
  }

  // ฟังก์ชันช่วยสร้าง ExpansionTile พร้อมการจัดรูปแบบ
  Widget _buildExpansionTile({
    required String title, // ชื่อหัวข้อ
    String? content,  // เนื้อหาข้อความ
    Widget? contentWidget,  // เนื้อหาแบบ Widget (ถ้ามี)
    //Color? cardColor, // สีพื้นหลังของ Card
  }) {
    return Card(  // ใช้ Card เพื่อเพิ่มเงาและขอบให้กับ ExpansionTile
      //color: cardColor ?? const Color(0xFFFFE0B2), // ใช้สีที่ส่งมา ถ้าไม่ส่งจะเป็นสีค่าเริ่มต้น
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile( // ใช้ ExpansionTile เพื่อให้สามารถขยาย/ย่อข้อมูลได้
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [ // เนื้อหาภายใน ExpansionTile
          Padding(
            padding: const EdgeInsets.all(16),
            child: contentWidget ??
                Text(
                  content ?? '',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.start,
                ),
          ),
        ],
      ),
    );
  }

  // สร้างส่วนแสดงคำแนะนำการดูแลแต่ละช่วงวัย
  Widget _buildLifeStageSection() {
    return Card(
      //color: const Color(0xFFFFD180),  
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        title: const Text(
          'คำแนะนำการดูแลแต่ละช่วงวัย',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 89, 57, 45),
          ),
        ),
        // แสดงคำแนะนำการดูแลแต่ละช่วงวัย
        children: lifeStages.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text( // ชื่อช่วงวัย
                  entry.key,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text( // ข้อความคำแนะนำการดูแล
                  entry.value,
                  style: const TextStyle(fontSize: 15),
                ),
                const Divider(),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}