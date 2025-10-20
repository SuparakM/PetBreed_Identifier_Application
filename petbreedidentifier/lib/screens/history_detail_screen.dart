import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/breed_age_mapper.dart';
import '../models/pet_model.dart';
import '../services/pet_service.dart';

class HistoryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item; // รายการประวัติที่จะแสดงรายละเอียด

  const HistoryDetailScreen({super.key, required this.item});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  bool isBreedExpanded = true; // สถานะการขยายของแท็บสายพันธุ์
  // ตัวควบคุมการจับภาพหน้าจอ
  final ScreenshotController _screenshotController = ScreenshotController();

  List<Pet?> currentPetModels = []; // รายการข้อมูล Pet Model ที่โหลดจาก Service
  List<String> ageTipsList = []; // คำแนะนำการดูแลตามช่วงวัย
  //  รายการสัตว์ที่ตรวจจับในภาพพร้อม label, confidence, color, age
  List<Map<String, dynamic>> detectedPets = [];

  @override
  void initState() {
    super.initState();
    _loadDetectedPets();
    _loadPetModels();
    _loadAgeTips();
  }

  // แปลง widget.item['boxes'] เป็น List<Map> สำหรับนำไปแสดง
  void _loadDetectedPets() {
    try {
      final raw = widget.item['boxes'];
      if (raw is String) {
        detectedPets = List<Map<String, dynamic>>.from(json.decode(raw));
      } else if (raw is List) {
        detectedPets = List<Map<String, dynamic>>.from(raw);
      } else {
        detectedPets = [];
      }
    } catch (_) {
      detectedPets = [];
    }
  }

  // โหลดข้อมูลสายพันธุ์จาก PetService.getBreedByName
  Future<void> _loadPetModels() async {
    List<Map<String, dynamic>> breedsJson = [];
    try {
      final raw = widget.item['breeds'];
      if (raw is String) {
        breedsJson = List<Map<String, dynamic>>.from(json.decode(raw));
      } else if (raw is List) {
        breedsJson = List<Map<String, dynamic>>.from(raw);
      }
    } catch (_) {}

    final List<Pet?> pets = [];
    for (var breedData in breedsJson) {
      final breedName = breedData['breed']?.toString() ?? '';
      if (breedName.isEmpty) continue;
      final pet = await PetService.getBreedByName(breedName);
      pets.add(pet);
    }
    if (mounted) setState(() => currentPetModels = pets);
  }

  // โหลด JSON lifestage_care.json เพื่อให้คำแนะนำช่วงวัยตามสัตว์ที่ตรวจจับ
  Future<void> _loadAgeTips() async {
    ageTipsList.clear();

    dynamic agesRaw = widget.item['ages'];
    List<dynamic> agesJson = [];

    if (agesRaw == null) {
      agesJson = [];
    } else if (agesRaw is String) {
      try {
        final decoded = json.decode(agesRaw);
        if (decoded is List) agesJson = decoded;
      } catch (_) {
        agesJson = [agesRaw];
      }
    } else if (agesRaw is List) {
      agesJson = agesRaw;
    }

    if (agesJson.isEmpty) return;

    try {
      final jsonString =
          await rootBundle.loadString('assets/data/lifestage_care.json');
      final jsonData = json.decode(jsonString);

      for (int i = 0; i < detectedPets.length; i++) {
        final type = _getAnimalType(detectedPets[i]['label'] ?? '');
        final typeKey = convertAnimalType(type);

        final ageStage = (i < agesJson.length)
            ? (agesJson[i] is Map
                ? agesJson[i]['ageStage']?.toString() ?? ''
                : agesJson[i].toString())
            : '';

        final tip = jsonData[typeKey]?[ageStage]?.toString() ?? '';
        ageTipsList.add(tip);
      }
    } catch (_) {
      ageTipsList.clear();
    }

    if (mounted) setState(() {});
  }

  // ดึงประเภทสัตว์ (dog/cat) จาก label
  String _getAnimalType(String label) {
    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('dog')) return 'dog';
    if (lowerLabel.contains('cat')) return 'cat';
    return 'unknown';
  }

  // แปลงประเภทสัตว์เป็นภาษาไทย
  String convertAnimalType(String type) {
    switch (type.toLowerCase()) {
      case 'dog':
        return 'สุนัข';
      case 'cat':
        return 'แมว';
      default:
        return type;
    }
  }

  /// แปลง hex string ของสีเป็น Color
  Color hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex'; // เติม alpha
    return Color(int.parse(hex, radix: 16));
  }

  /// ดึงสีของ box จาก DB
  Color _getBoxColor(int index) {
    try {
      final boxData = detectedPets[index]; // ข้อมูลการตรวจจับ
      final colorHex = boxData['color']?.toString() ?? ''; // ค่า hex ของสี
      return hexToColor(colorHex); // แปลงเป็น Color
    } catch (_) {
      return Colors.grey; //ถ้าไม่มีข้อมูล ใช้สีเทา
    }
  }

  // Capture screenshot ของ Card และแชร์ผ่าน Share Plus
  Future<void> _shareResult() async {
    try {
      final imageFile = await _screenshotController.capture();
      if (imageFile == null) return;

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/history_result.png';
      final file = File(filePath);
      await file.writeAsBytes(imageFile);

      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      debugPrint("แชร์ไม่สำเร็จ: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawDate = widget.item['datetime'] ?? ''; // ดึงวันที่ดิบจาก DB
    String date = rawDate; // กำหนดค่าเริ่มต้นเป็นวันที่ดิบ
    try {
      final parsed = DateTime.tryParse(rawDate); // แปลงเป็น DateTime
      if (parsed != null) {
        date =
            "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
      }
    } catch (_) {}
    // ดึง path ของรูปภาพที่จะแสดง
    final imagePath =
        widget.item['boxedImage'] ?? widget.item['originalImage'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFA726),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCE8426),
        centerTitle: true,
        title: const Text('รายละเอียด',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareResult,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    // แสดงวันที่
                    Center(
                      child: Text(
                        date,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    //แสดงภาพสัตว์
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16), // ระยะห่างซ้าย-ขวา
                      child: Screenshot(
                        controller: _screenshotController, // controller คือ _screenshotController → ใช้ capture รูปภาพของ Widget ด้านใน
                        //  child คือ Widget ที่เราต้องการ capture
                        child: Card(
                          elevation: 4, // ความลึกเงา
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // มุมโค้งมน
                          ),
                          clipBehavior: Clip.antiAlias, // ตัดขอบมุมโค้ง
                          child: SizedBox(
                            height:
                                MediaQuery.of(context).size.height * 0.35, // กำหนดความสูงเป็น 35% ของความสูงหน้าจอ
                            width: double.infinity, // กำหนดความกว้างเต็มที่
                            // แสดงภาพจากไฟล์
                            child: (imagePath != null && File(imagePath).existsSync())
                              ? Image.file(File(imagePath), fit: BoxFit.contain)
                                : const Center(child: Text('ไม่มีรูปภาพ')),
                              /*ถ้ามี → แสดงภาพด้วย Image.file
                                fit: BoxFit.contain → ภาพปรับขนาดให้พอดี ไม่ถูกตัด
                              ถ้าไม่มี → แสดงข้อความ “ไม่มีรูปภาพ” อยู่ตรงกลาง*/
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // แท็บ “สายพันธุ์” / “ช่วงวัย”
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _buildTab('สายพันธุ์', isBreedExpanded,
                                    () => setState(() => isBreedExpanded = true)),
                                _buildTab('ช่วงวัย', !isBreedExpanded,
                                    () => setState(() => isBreedExpanded = false)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity, // ความกว้างเต็มที่
                      margin: const EdgeInsets.symmetric(horizontal: 16), // ระยะห่างซ้าย-ขวา
                      padding: const EdgeInsets.all(12), // ระยะห่างรอบด้านใน
                      decoration: const BoxDecoration(
                        color: Color(0xFFCE8426),
                        // ขอบมุมล่างโค้ง
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(10), // มุมล่างซ้ายโค้ง
                          bottomRight: Radius.circular(10), // มุมล่างขวาโค้ง
                        ),
                      ),
                      // แสดงรายการสายพันธุ์หรือช่วงวัยที่ตรวจพบ
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: detectedPets.asMap().entries.map((entry) {
                          final index = entry.key;  // ดัชนีของสัตว์ที่ตรวจพบ
                          final detection = entry.value;  // ข้อมูลการตรวจจับของสัตว์
                          final breed = BreedAgeMapper.mapBreed(detection['label'] ?? '');
                          final breedConfidence =
                              ((detection['confidence'] ?? 0.0) * 100)
                                  .toStringAsFixed(1);  // ความมั่นใจสายพันธุ์
                          final ageRange = BreedAgeMapper.mapAge(detection['ageRange'] ?? '');
                          final ageConfidence =
                              ((detection['ageConfidence'] ?? 0.0) * 100)
                                  .toStringAsFixed(1);  // ความมั่นใจช่วงวัย
                          final boxColor = _getBoxColor(index); // ดึงสีของ box
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4), // ระยะห่างบน-ล่าง
                            child: Row(
                              children: [
                                Container(
                                  width: 14, // ขนาดกล่องสี
                                  height: 14, // ขนาดกล่องสี
                                  margin: const EdgeInsets.only(right: 8), // ระยะห่างขวา
                                  decoration: BoxDecoration(
                                    color: boxColor, // ใช้สีจากข้อมูล
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                // แสดงชื่อสายพันธุ์หรือช่วงวัย
                                Expanded(
                                  child: Text(
                                    isBreedExpanded
                                        ? '$breed ($breedConfidence%)'
                                        : '$ageRange ($ageConfidence%)',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // แสดงรายละเอียดสายพันธุ์หรือช่วงวัย
                    Expanded(
                      child: SingleChildScrollView(
                        child: isBreedExpanded
                            ? _buildBreedDetails()
                            : _buildAgeDetails(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // สร้างแท็บสำหรับสลับระหว่างสายพันธุ์และช่วงวัย
  Widget _buildTab(String title, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFCE8426) : const Color(0xFFFFA726),
            borderRadius: BorderRadius.only(
              topLeft: title == 'สายพันธุ์' ? const Radius.circular(10) : Radius.zero,
              topRight: title == 'ช่วงวัย' ? const Radius.circular(10) : Radius.zero,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // สร้างรายละเอียดสายพันธุ์
  Widget _buildBreedDetails() {
    if (currentPetModels.isEmpty) return const Center(child: CircularProgressIndicator());
    final displayed = <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: currentPetModels.asMap().entries.map((entry) {
        final index = entry.key;
        final petModel = entry.value;
        final breed = BreedAgeMapper.mapBreed(detectedPets[index]['label'] ?? '');

        //final boxColor = _getBoxColor(index); // ดึงสีเดียวกับกรอบ Bounding Box

        if (breed.isEmpty || displayed.contains(breed)) return const SizedBox.shrink();
        displayed.add(breed);

        if (petModel == null) return Padding(padding: const EdgeInsets.all(8.0), child: Text("ไม่พบข้อมูลสำหรับ $breed"));

        return Card(
          //color: boxColor.withAlpha(100), // ใช้สีเดียวกับกรอบ Bounding Box แต่ใส่ความโปร่งใส
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            title: Text(breed, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 89, 57, 45))),
            children: [
              _buildInnerExpansionTile('ประวัติ', petModel.history),
              _buildInnerExpansionTile('อุปนิสัย', petModel.personality),
              _buildInnerExpansionTile('อายุขัยเฉลี่ย', petModel.lifespan),
              _buildInnerExpansionTile(
                'สิ่งที่ต้องรู้ก่อนรับเลี้ยง',
                null,
                customWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // จัดแนวข้อความทางซ้าย
                  children: petModel.careTips.map((tip) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4), // ระยะห่างบน-ล่าง
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('• '), Expanded(child: Text(tip))]),
                  )).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // สร้าง ExpansionTile ย่อยสำหรับรายละเอียดสายพันธุ์
  Widget _buildInnerExpansionTile(
    String title,// ชื่อหัวข้อ
    // เนื้อหาข้อความ
    String? content, {
      Widget? customWidget,
    }
  ) {
    return ExpansionTile(
      title: Text(
        title, // ชื่อหัวข้อ
        style: const TextStyle(
          fontWeight: FontWeight.w600, // ตัวหนาปานกลาง
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12), // ระยะห่างรอบด้านใน
          child: customWidget ?? // ถ้ามี widget กำหนดมาให้ใช้ ถ้าไม่มีใช้ Text แสดงเนื้อหา
              Text(
                content ?? '', // เนื้อหาข้อความ
                style: const TextStyle(fontSize: 16),
              ),
        ),
      ],
    );
  }

  // สร้างรายละเอียดช่วงวัย
  Widget _buildAgeDetails() {
    if (ageTipsList.isEmpty) return const Center(child: Text('ไม่มีคำแนะนำช่วงวัย'));
    final displayed = <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ageTipsList.asMap().entries.map((entry) {
        final index = entry.key;
        final tips = entry.value;
        final ageRange = BreedAgeMapper.mapAge(detectedPets[index]['ageRange'] ?? '');

        //final boxColor = _getBoxColor(index); // ดึงสีเดียวกับกรอบ Bounding Box

        if (ageRange.isEmpty || displayed.contains(ageRange)) return const SizedBox.shrink();
        displayed.add(ageRange);

        return Card(
          //color: boxColor.withAlpha(100), // ใช้สีเดียวกับกรอบ Bounding Box แต่ใส่ความโปร่งใส
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ExpansionTile(
            title: Text('คำแนะนำการดูแลช่วงวัยของ $ageRange', style: const TextStyle(fontWeight: FontWeight.bold)),
            children: [Padding(padding: const EdgeInsets.all(16), child: Text(tips, style: const TextStyle(fontSize: 16)))],
          ),
        );
      }).toList(),
    );
  }
}