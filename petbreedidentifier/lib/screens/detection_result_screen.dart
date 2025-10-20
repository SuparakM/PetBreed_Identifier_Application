import 'dart:io'; //จัดการไฟล์
import 'dart:convert'; //แปลงข้อมูล JSON
import 'dart:math';
import 'package:image/image.dart' as img; //อ่านขนาดภาพ
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; //จัดรูปแบบวันที่
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart'; //แชร์
import 'package:path_provider/path_provider.dart'; //จัดการเส้นทางไฟล์
import 'package:screenshot/screenshot.dart'; //จับภาพหน้าจอ

import '../models/pet_model.dart';
import '../services/pet_service.dart';
import '../services/db_helper.dart';
import '../utils/breed_age_mapper.dart';
import 'main_screen.dart';

class DetectionResultScreen extends StatefulWidget {
  final String imagePath; 
  final List<Map<String, dynamic>> detectedPets; 

  const DetectionResultScreen({
    super.key,
    required this.imagePath,
    required this.detectedPets,
  });

  @override
  State<DetectionResultScreen> createState() => _DetectionResultScreenState();
}

class _DetectionResultScreenState extends State<DetectionResultScreen> {
  int currentIndex = 0; //index ของภาพ (กรณีหลายตัวในภาพเดียว)
  bool isBreedExpanded = true; //สลับโหมดระหว่าง “สายพันธุ์” กับ “ช่วงวัย”

  final Map<String, Color> _labelColors = {}; //Map เก็บสีของกรอบแต่ละตัว
  final List<Pet?> allPetModels = []; //รายการข้อมูลของสัตว์แต่ละตัว
  final List<String?> ageTipsList = []; //คำแนะนำการดูแลแต่ละช่วงวัย

  //ใช้จับภาพหน้าจอเพื่อแชร์/บันทึก
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    if (widget.detectedPets.isNotEmpty) {
      _loadAllPets().then((_) => _loadAllAgeTips()); //โหลดข้อมูลสัตว์และคำแนะนำช่วงวัย
    }
  }

  // ดึงข้อมูลสายพันธุ์
  Future<void> _loadAllPets() async {
    allPetModels.clear();

    for (var pet in widget.detectedPets) {
      final label = pet['label'] ?? '';
      final breedName = BreedAgeMapper.mapBreed(label);
      if (breedName.isEmpty) {
        allPetModels.add(null);
      } else {
        final petModel = await PetService.getBreedByName(breedName);
        allPetModels.add(petModel);
      }
    }
    setState(() {});
  }

  // ดึงคำแนะนำช่วงวัยทุกตัว
  Future<void> _loadAllAgeTips() async {
    ageTipsList.clear();
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/lifestage_care.json');
      final jsonData = json.decode(jsonString);

      for (var pet in widget.detectedPets) {
        final label = pet['label'] ?? '';
        final rawAge = pet['ageRange'] ?? '';
        final ageKey = BreedAgeMapper.ageMapping[rawAge] ?? rawAge;
        final typeKey = convertAnimalType(_getAnimalType(label));
        final tips = jsonData[typeKey]?[ageKey]?.toString();
        ageTipsList.add(tips);
      }
    } catch (e) {
      ageTipsList.clear();
    }
    setState(() {});
  }

  //ใช้ตรวจว่า label นั้นเป็น “สุนัข” หรือ “แมว”
  String _getAnimalType(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('dog')) return 'dog';
    if (lower.contains('cat')) return 'cat';
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

  // จับภาพหน้าจอผลลัพธ์ แล้วแชร์ผ่านแอปอื่น
  Future<void> _shareResult() async {
    try {
      final imageFile = await _screenshotController.capture();
      if (imageFile == null) return;

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/result.png';
      final file = File(filePath);
      await file.writeAsBytes(imageFile);

      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      debugPrint("แชร์ไม่สำเร็จ: $e");
    }
  }

  // บันทึกผลการตรวจจับทั้งหมดลงฐานข้อมูล SQLite
  Future<void> _saveToHistory() async {
    if (widget.detectedPets.isEmpty) return;

    try {
      final now = DateTime.now();
      final dateString = DateFormat('yyyy-MM-dd').format(now);

      final boxedBytes = await _screenshotController.capture();
      if (boxedBytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final originalPath = widget.imagePath;
      final boxedPath = '${tempDir.path}/boxed_${now.millisecondsSinceEpoch}.png';
      final boxedFile = File(boxedPath);
      await boxedFile.writeAsBytes(boxedBytes);

      final List<Map<String, dynamic>> breedsInfo = [];
      final List<Map<String, dynamic>> agesInfo = [];
      final List<Map<String, dynamic>> breedDetailsList = [];
      final List<Map<String, dynamic>> ageTipsListJson = [];

      for (int i = 0; i < widget.detectedPets.length; i++) {
        final detection = widget.detectedPets[i];
        final label = detection['label'] ?? '';
        final ageRange = detection['ageRange'] ?? '';
        final breedConfidence = ((detection['confidence'] ?? 0.0) * 100).toStringAsFixed(1);
        final ageConfidence = ((detection['ageConfidence'] ?? 0.0) * 100).toStringAsFixed(1);
        final species = _getAnimalType(label);

        breedsInfo.add({
          'breed': BreedAgeMapper.mapBreed(label),
          'confidence': breedConfidence,
          'species': species,
        });

        agesInfo.add({
          'ageStage': BreedAgeMapper.mapAge(ageRange),
          'confidence': ageConfidence,
        });

        final petModel = (i < allPetModels.length) ? allPetModels[i] : null; 
        if (petModel != null) { breedDetailsList.add(petModel.toJsonMap()); }

        final tips = (i < ageTipsList.length) ? ageTipsList[i] : ''; 
        if (tips != null && tips.isNotEmpty) { ageTipsListJson.add({ 'ageStage': BreedAgeMapper.mapAge(ageRange), 'tips': tips, }); }
      }

      final List<Map<String, dynamic>> boxes = widget.detectedPets.asMap().entries.map((entry) {
        final index = entry.key;
        final detection = entry.value;
        return {
          'x': detection['x'] ?? 0.0,
          'y': detection['y'] ?? 0.0,
          'w': detection['w'] ?? 0.0,
          'h': detection['h'] ?? 0.0,
          'label': detection['label'] ?? '',
          'color': _labelColors[index.toString()]?.toARGB32().toRadixString(16), // สีเป็น hex
          'confidence': detection['confidence'] ?? 0.0,
          'ageRange': detection['ageRange'] ?? '',
          'ageConfidence': detection['ageConfidence'] ?? 0.0,
        };
      }).toList();

      final historyData = {
        'datetime': dateString,
        'originalImage': originalPath,
        'boxedImage': boxedPath,
        'breeds': jsonEncode(breedsInfo),
        'ages': jsonEncode(agesInfo),
        'breedDetails': jsonEncode(breedDetailsList),
        'ageTips': jsonEncode(ageTipsListJson),
        'boxes': jsonEncode(boxes),
      };

      await DBHelper.insertHistory(historyData);

      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 2)),
          (route) => false,
        );
      });
    } catch (e) {
      debugPrint('บันทึกไม่สำเร็จ: $e');
    }
  }

  // สร้างสีของกรอบ Bounding Box
  Color _colorFromIndex(int index) {
    final key = index.toString();
    // ถ้ามีสีอยู่แล้วให้ใช้สีเดิม
    if (_labelColors.containsKey(key)) {
      return _labelColors[key]!; // ใช้สีเดิม
    }
    // สุ่มจากค่า Random เพื่อให้แต่ละกล่องสีไม่ซ้ำกัน
    final rnd = Random(index + DateTime.now().millisecondsSinceEpoch);
    // สร้างสีสุ่มที่สว่างพอ
    final color = Color.fromARGB(
      255,
      100 + rnd.nextInt(155),
      100 + rnd.nextInt(155),
      100 + rnd.nextInt(155),
    );
    _labelColors[key] = color; // เก็บสีไว้ในแมพ
    return color;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.detectedPets.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('ไม่พบข้อมูลสัตว์เลี้ยง')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFA726),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCE8426),
        centerTitle: true,
        title: const Text(
          'ผลลัพธ์',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // ปุ่มย้อนกลับ
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen(initialIndex: 0)),
              (route) => false,
            );
          },
        ),
        // ปุ่มแชร์
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
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Screenshot(
                        controller: _screenshotController,
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.35,
                            width: double.infinity,
                            child: (widget.imagePath.isNotEmpty &&
                                    File(widget.imagePath).existsSync())
                                ? _buildDetectionPreview()
                                : const Center(child: Text('ไม่มีรูปภาพ')),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ปุ่มสลับแท็บ (สายพันธุ์ / ช่วงวัย)
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    // รายการสัตว์ที่ตรวจพบ
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFCE8426),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.detectedPets.asMap().entries.map((entry) {
                          final index = entry.key;
                          final detection = entry.value;
                          final label = detection['label'] ?? '';
                          final age = detection['ageRange'] ?? '';
                          final breedConfidence =
                              ((detection['confidence'] ?? 0.0) * 100).toStringAsFixed(1);
                          final ageConfidence =
                              ((detection['ageConfidence'] ?? 0.0) * 100).toStringAsFixed(1);

                          final breed = BreedAgeMapper.mapBreed(label);
                          final ageRange = BreedAgeMapper.mapAge(age);
                          final boxColor = _colorFromIndex(index); // สีกรอบ

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  margin: const EdgeInsets.only(right: 8),
                                  // กรอบสี
                                  decoration: BoxDecoration(
                                    color: boxColor, // สีของกรอบ Bounding Box
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                // ชื่อสายพันธุ์/ช่วงวัย + ความมั่นใจ
                                Expanded(
                                  child: Text(
                                    isBreedExpanded
                                        ? '$breed ($breedConfidence%)'
                                        : '$ageRange ($ageConfidence%)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // รายละเอียดแต่ละสายพันธุ์/ช่วงวัย
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _saveToHistory,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text(
            'บันทึกลงประวัติ',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // ส่วนที่วาดภาพ + กรอบ Bounding Box
  Widget _buildDetectionPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth; // ความกว้างหน้าจอ
        final screenHeight = constraints.maxHeight; // ความสูงหน้าจอ

        final bytes = File(widget.imagePath).readAsBytesSync(); // อ่านไฟล์ภาพ
        final image = img.decodeImage(bytes)!; // แปลงเป็นภาพ
        final imageWidth = image.width.toDouble(); // ความกว้างภาพ
        final imageHeight = image.height.toDouble(); // ความสูงภาพ

        final scaleX = screenWidth / imageWidth; // สเกลแนวนอน
        final scaleY = screenHeight / imageHeight; // สเกลแนวตั้ง
        final scale = min(scaleX, scaleY); // เลือกสเกลที่เล็กกว่า

        final displayWidth = imageWidth * scale; // ความกว้างที่แสดง
        final displayHeight = imageHeight * scale; // ความสูงที่แสดง

        const innerPadding = 0.0; // ระยะห่างจากขอบภาพ
        final offsetX = (screenWidth - displayWidth) / 2 + innerPadding; // ตำแหน่งเริ่มต้นแกน X
        final offsetY = (screenHeight - displayHeight) / 2 + innerPadding; // ตำแหน่งเริ่มต้นแกน Y
        final adjustedWidth = displayWidth - innerPadding * 2; // ความกว้างที่แสดงหลังหัก padding
        final adjustedHeight = displayHeight - innerPadding * 2; // ความสูงที่แสดงหลังหัก padding

        return Stack(
          children: [
            Positioned(
              left: offsetX, // ตำแหน่งเริ่มต้นแกน X
              top: offsetY, // ตำแหน่งเริ่มต้นแกน Y
              width: displayWidth, // ความกว้างที่แสดง
              height: displayHeight, // ความสูงที่แสดง
              // แสดงภาพ
              child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
            ),
            ...widget.detectedPets.asMap().entries.map((entry) {
              final index = entry.key;  // ดัชนีของสัตว์ที่ตรวจพบ
              final detection = entry.value; // ข้อมูลการตรวจจับของสัตว์

              // คำนวณตำแหน่งและขนาดของกรอบ Bounding Box
              final x = ((detection['x'] as num?)?.toDouble() ?? 0.0) * scale + offsetX;
              final y = ((detection['y'] as num?)?.toDouble() ?? 0.0) * scale + offsetY;
              final w = ((detection['w'] as num?)?.toDouble() ?? 0.0) * scale;
              final h = ((detection['h'] as num?)?.toDouble() ?? 0.0) * scale;

              final breed = detection['label'] ?? '';
              final confidence = ((detection['confidence'] ?? 0.0) * 100).toStringAsFixed(1);
              final ageRange = detection['ageRange'] ?? '';
              final ageConfidence = ((detection['ageConfidence'] ?? 0.0) * 100).toStringAsFixed(1);

              final boxColor = _colorFromIndex(index); // สีสำหรับกรอบ 

              return Positioned(
                // จำกัดไม่ให้กรอบเกินขอบภาพ
                left: x.clamp(offsetX, offsetX + adjustedWidth - w),
                top: y.clamp(offsetY, offsetY + adjustedHeight - h),
                width: min(w, adjustedWidth),
                height: min(h, adjustedHeight),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: boxColor, width: 2), // สีสำหรับกรอบ Bounding Box
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      color: boxColor.withAlpha(180), // สีพื้นหลังป้ายกำกับ
                      padding: const EdgeInsets.all(4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$breed $confidence%\n$ageRange $ageConfidence%',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  /// สร้างแท็บสำหรับสลับระหว่างสายพันธุ์และช่วงวัย
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
          child: Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  /// รายละเอียดสายพันธุ์สัตว์เลี้ยง
  Widget _buildBreedDetails() {
    if (allPetModels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final displayedBreeds = <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: allPetModels.asMap().entries.map((entry) {
        final index = entry.key;
        final petModel = entry.value;
        final detection = widget.detectedPets[index];
        final label = detection['label'] ?? '';
        final breed = BreedAgeMapper.mapBreed(label);
        //final boxColor = _colorFromIndex(index); // ดึงสีเดียวกับกรอบ Bounding Box

        if (breed.isEmpty || displayedBreeds.contains(breed)) {
          return const SizedBox.shrink();
        }
        displayedBreeds.add(breed);

        if (petModel == null) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("ไม่พบข้อมูลสำหรับ $breed"),
          );
        }

        // การ์ดหลัก = ชื่อสายพันธุ์
        return Card(
          //color: boxColor.withAlpha(100), // ใช้สีเดียวกับกรอบ Bounding Box แต่ใส่ความโปร่งใส
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            title: Text(
              breed,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 89, 57, 45),
              ),
            ),
            children: [
              _buildInnerExpansionTile('ประวัติ', petModel.history),
              _buildInnerExpansionTile('อุปนิสัย', petModel.personality),
              _buildInnerExpansionTile('อายุขัยเฉลี่ย', petModel.lifespan),
              _buildInnerExpansionTile(
                'สิ่งที่ต้องรู้ก่อนรับเลี้ยง',
                null,
                customWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: petModel.careTips.map((tip) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontSize: 16)),
                          Expanded(child: Text(tip, style: const TextStyle(fontSize: 16))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// ExpansionTile ย่อยด้านใน (หัวข้อย่อยแต่ละอัน)
  Widget _buildInnerExpansionTile(String title, String? content, {Widget? customWidget}) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: customWidget ??
              Text(
                content ?? '',
                style: const TextStyle(fontSize: 16),
              ),
        ),
      ],
    );
  }

  // แสดงคำแนะนำการดูแลแต่ละช่วงวัย
  Widget _buildAgeDetails() {
    if (ageTipsList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final displayedAges = <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.detectedPets.asMap().entries.map((entry) {
        final index = entry.key;
        final detection = entry.value;

        final age = detection['ageRange'] ?? '';
        final ageRange = BreedAgeMapper.mapAge(age);

        //final boxColor = _colorFromIndex(index); // ดึงสีเดียวกับกรอบ Bounding Box

        // กันข้อมูลซ้ำ เช่น ถ้ามีสัตว์หลายตัวที่ช่วงวัยเดียวกัน
        if (ageRange.isEmpty || displayedAges.contains(ageRange)) {
          return const SizedBox.shrink();
        }
        displayedAges.add(ageRange);

        final tips = (index < ageTipsList.length) ? ageTipsList[index] : '';

        return Card(
          //color: boxColor.withAlpha(100), // ใช้สีเดียวกับกรอบ Bounding Box แต่ใส่ความโปร่งใส
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            title: Text(
              'คำแนะนำการดูแลช่วงวัยของ $ageRange',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 89, 57, 45),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  (tips != null && tips.isNotEmpty) ? tips : 'ไม่พบคำแนะนำสำหรับช่วงวัยนี้',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}