import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

/// จุดเริ่มต้นของแอปพลิเคชัน
void main() { 
  runApp(const PetBreedApp());
}

/// "โครงสร้างหลักของแอปฯ" 
class PetBreedApp extends StatelessWidget {
  const PetBreedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetBreed Identifier', /// ชื่อแอปฯ
      debugShowCheckedModeBanner: false,  /// ปิดแถบ Debug
      home: const SplashScreen(), /// หน้าแรกที่แสดงเมื่อเปิดแอปฯ
    );
  }
}

/// การสร้างหน้าจอเริ่มต้น โดยใช้ StatefulWidget 
/// (เพราะเราต้องการให้มัน "ทำอะไรบางอย่าง" คือการเปลี่ยนหน้าเองได้)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// สถานะของหน้าจอเริ่มต้น
class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // รอ 3 วินาทีแล้วไปหน้าข้อมูลสายพันธุ์
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return; // เช็กก่อนใช้ context
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    });
  }

  /// การสร้าง UI ของหน้าจอเริ่มต้น
  @override
  Widget build(BuildContext context) {
    return Scaffold( // การสร้าง "กรอบหน้าจอ" (Scaffold)
      backgroundColor: const Color(0xFFFFA726), // กำหนดให้พื้นหลังเป็นสีส้มสดใส
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // กำหนดขนาดตามหน้าจอ
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            return Center(
              child: Column( /// การจัดวางองค์ประกอบ ให้อยู่ตรงกลางหน้าจอ โดยเรียงจากบนลงล่าง
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // รูปภาพสัตว์
                  SizedBox(
                    height: height * 0.3,
                    child: Image.asset(
                      'assets/images/pets.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: height * 0.03),
                  Text(
                    'PetBreed Identifier',
                    style: TextStyle(
                      fontSize: width * 0.06, // ปรับขนาดตามหน้าจอ
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: height * 0.05),
                  // โหลดหมุน
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                    strokeWidth: 3.5,
                  ),
                  SizedBox(height: height * 0.02),
                  Text(
                    'เริ่มต้นการใช้งาน...',
                    style: TextStyle(
                      fontSize: width * 0.04,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}