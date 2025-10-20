import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'detection_result_screen.dart';

class AnalyzingScreen extends StatefulWidget {
  final String imagePath; // เส้นทางภาพที่ต้องการวิเคราะห์

  const AnalyzingScreen({super.key, required this.imagePath});

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  List<Map<String, dynamic>> _detections = []; // รายการผลการตรวจจับ
  bool _loading = true; // สถานะการโหลดข้อมูล

  // ขนาดภาพจริง
  late double _imageWidth;
  late double _imageHeight; 

  @override
  void initState() {
    super.initState();
    _loadImageSize(); // โหลดขนาดภาพจริง
    _analyzeImage();  // เริ่มวิเคราะห์ภาพ
  }

  // โหลดขนาดภาพจริง
  void _loadImageSize() {
    final file = File(widget.imagePath);  // อ่านไฟล์ภาพ
    final bytes = file.readAsBytesSync(); // อ่านเป็น bytes
    final image = img.decodeImage(bytes)!;  // แปลงเป็น image object
    _imageWidth = image.width.toDouble(); // กำหนดความกว้าง
    _imageHeight = image.height.toDouble(); // กำหนดความสูง
  }

  // ฟังก์ชันวิเคราะห์ภาพ
  Future<void> _analyzeImage() async {
    try {
      // ส่งคำขอไปยังเซิร์ฟเวอร์
      final uri = Uri.parse('http://10.0.2.2:8000/analyze'); // URL ของเซิร์ฟเวอร์
      var request = http.MultipartRequest('POST', uri); // สร้างคำขอแบบ Multipart 

      // เพิ่มไฟล์ภาพและฟิลด์อื่นๆ
      request.files.add(await http.MultipartFile.fromPath('files', widget.imagePath));
      request.fields['save_result'] = 'false';  // ไม่บันทึกผลลัพธ์บนเซิร์ฟเวอร์

      // ส่งคำขอและรอรับการตอบกลับ
      final streamedResponse = await request.send();
      final respStr = await streamedResponse.stream.bytesToString();

      // ตรวจสอบสถานะการตอบกลับ
      if (streamedResponse.statusCode != 200) {
        _showError("เกิดข้อผิดพลาดจากเซิร์ฟเวอร์");
        return;
      }

      // แปลงผลลัพธ์จาก JSON
      final jsonResp = json.decode(respStr);
      final results = jsonResp['results'] as List;

      // ตรวจสอบว่ามีการตรวจจับหรือไม่
      if (results.isEmpty || results[0]['detections'] == null) {
        _showError("ไม่พบสัตว์ในภาพ");
        return;
      }

      final detections = <Map<String, dynamic>>[];  // รายการผลการตรวจจับ
      // แปลงผลลัพธ์ให้เป็นรูปแบบที่ต้องการ
      for (var det in results[0]['detections']) {
        final bbox = det['bbox'] as List<dynamic>;  // กรอบล้อมรอบการตรวจจับ
        detections.add({  // เพิ่มผลการตรวจจับลงในรายการ
          "label": det['label'],
          "confidence": det['confidence'],
          "ageRange": det['age_range'],
          "ageConfidence": det['age_confidence'],
          "x": bbox[0], // ตำแหน่งแกน X
          "y": bbox[1], // ตำแหน่งแกน Y
          "w": bbox[2] - bbox[0], // ความกว้าง
          "h": bbox[3] - bbox[1], // ความสูง
        });
      }

      // ตรวจสอบว่ามีการตรวจจับหรือไม่
      if (!mounted) return;
      // อัปเดตสถานะการโหลด
      setState(() {
        _detections = detections;  // อัปเดตผลการตรวจจับ
        _loading = false;  // เปลี่ยนสถานะการโหลด
      });

      // ไปหน้าผลลัพธ์ทันที
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DetectionResultScreen(
            imagePath: widget.imagePath,
            detectedPets: _detections,
          ),
        ),
      );

    } catch (e) {
      _showError("วิเคราะห์ไม่สำเร็จ: $e");
    }
  }

  // หากเกิดปัญหา ให้แสดงแถบแจ้งเตือนข้อความ (SnackBar) และ เด้งกลับไปหน้าจอก่อนหน้า
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final screenWidth = constraints.maxWidth; // ความกว้างหน้าจอ
        final screenHeight = constraints.maxHeight; // ความสูงหน้าจอ

        // คำนวณ scale ของ BoxFit.cover
        final scaleX = screenWidth / _imageWidth; // สเกลแนวนอน
        final scaleY = screenHeight / _imageHeight; // สเกลแนวตั้ง
        final scale = scaleX > scaleY ? scaleX : scaleY; // เลือกสเกลที่ใหญ่กว่า

        final displayWidth = _imageWidth * scale; // ความกว้างที่แสดง
        final displayHeight = _imageHeight * scale; // ความสูงที่แสดง

        final offsetX = (screenWidth - displayWidth) / 2; // ตำแหน่งเริ่มต้นแกน X
        final offsetY = (screenHeight - displayHeight) / 2; // ตำแหน่งเริ่มต้นแกน Y

        return Stack(
          children: [
            // ภาพพื้นหลัง
            Positioned(
              left: offsetX, // ตำแหน่งเริ่มต้นแกน X
              top: offsetY, // ตำแหน่งเริ่มต้นแกน Y
              width: displayWidth, // ความกว้างที่แสดง
              height: displayHeight, // ความสูงที่แสดง
              // แสดงภาพ
              child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
            ),

            if (_loading)
              Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'กำลังวิเคราะห์...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}