import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'analyzing_screen.dart';

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key});

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  final ImagePicker _picker = ImagePicker();  // ตัวเลือกภาพ

  // เลือกรูปภาพจากแกลเลอรี
  Future<void> _pickFromGallery() async {
    // เปิดแกลเลอรีเพื่อเลือกรูปภาพ
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      await _analyzeAndNavigate(picked);  // วิเคราะห์และไปหน้าผลลัพธ์
    }
  }

  // ถ่ายรูปด้วยกล้อง
  Future<void> _takePhoto() async {
    // เปิดกล้องเพื่อถ่ายรูป
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null && mounted) {
      await _analyzeAndNavigate(picked);  // วิเคราะห์และไปหน้าผลลัพธ์
    }
  }

  // วิเคราะห์ภาพและไปหน้าผลลัพธ์
  Future<void> _analyzeAndNavigate(XFile picked) async {
    // ไปหน้ากำลังวิเคราะห์
    Navigator.push(
      context,
      MaterialPageRoute(  // สร้างเส้นทางไปหน้ากำลังวิเคราะห์
        builder: (_) => AnalyzingScreen(imagePath: picked.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(  // โครงสร้างหน้าจอ
      backgroundColor: const Color(0xFFFFA726),
      body: Stack(  // วางเลเยอร์ของวิดเจ็ต
        children: [ // วิดเจ็ตในเลเยอร์
          const Center( // ข้อความตรงกลางหน้าจอ
            child: Text(
              'กรุณาเลือกรูปภาพหรือถ่ายภาพ',
              style: TextStyle(color: Colors.black, fontSize: 20),
            ),
          ),
          Positioned( // ตำแหน่งปุ่มที่ด้านล่าง
            bottom: 0,
            left: 0,
            right: 0,
            child: Container( // กล่องปุ่ม
              color: const Color(0xFFFFA726),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row( // แถวของปุ่ม
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton( // ปุ่มเลือกจากแกลเลอรี
                    icon: const Icon(Icons.photo_library, size: 30),
                    onPressed: _pickFromGallery,
                  ),
                  GestureDetector(  // ปุ่มถ่ายรูป
                    onTap: _takePhoto,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 30), // ปุ่มสลับกล้อง (เว้นที่ไว้)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}