import 'package:flutter/material.dart';
import 'camera_preview_screen.dart';
import 'home_screen.dart';
import 'history_screen.dart';

// หน้าจอหลักที่มีการจัดการการนำทางระหว่างหน้าต่างๆ
class MainScreen extends StatefulWidget {
  final int initialIndex; // เป็นการกำหนดว่า หน้าจอเริ่มต้น ที่จะเปิดขึ้นมาควรเป็นหน้าไหน
  const MainScreen({super.key, this.initialIndex = 1});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex; // ดัชนีของหน้าจอที่ถูกเลือกในปัจจุบัน

  // รายการของหน้าจอที่สามารถนำทางไปได้ (กล้อง, หน้าหลัก, ประวัติ)
  final List<Widget> _pages = [
    const CameraPreviewScreen(),
    const HomeScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex; // กำหนดค่าดัชนีเริ่มต้นจากพารามิเตอร์ที่ส่งมา
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(  // โครงสร้างหลักของหน้าจอ
      body: IndexedStack( // ใช้ IndexedStack เพื่อเก็บสถานะของแต่ละหน้าจอ
        index: _selectedIndex,  // กำหนดหน้าจอที่จะแสดงตามดัชนีที่เลือก
        children: _pages, // รายการของหน้าจอที่สามารถนำทางไปได้
      ),
      bottomNavigationBar: Container( // แถบนำทางด้านล่าง
        height: 80,
        decoration: const BoxDecoration(
          color: Color(0xFFCE8426),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row( // แสดงไอคอนและป้ายกำกับสำหรับแต่ละหน้าจอ
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [ // ไอคอนและป้ายกำกับสำหรับแต่ละหน้าจอ
            _buildNavItem(Icons.camera_alt, 'ตัวระบุ', 0),
            _buildNavItem(Icons.home, 'หน้าหลัก', 1),
            _buildNavItem(Icons.history, 'ประวัติ', 2),
          ],
        ),
      ),
    );
  }

  // ฟังก์ชันช่วยสร้างรายการนำทางแต่ละรายการ พร้อมไอคอนและป้ายกำกับ ที่เปลี่ยนแปลงตามสถานะการเลือก
  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;  // ตรวจสอบว่ารายการนี้ถูกเลือกหรือไม่

    return GestureDetector( // ตรวจจับการแตะที่รายการ
      onTap: () {
        setState(() {
          _selectedIndex = index; // อัปเดตดัชนีที่เลือกและรีเฟรช UI
        });
      },
      child: AnimatedContainer( // ใช้ AnimatedContainer เพื่อให้การเปลี่ยนแปลงมีความนุ่มนวล
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFFFCC80), // สีพื้นหลังเมื่อเลือก
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Row(
          children: [
            Icon( // ไอคอนของรายการ
              icon,
              size: 30,
              color: isSelected ? Colors.black : Colors.black54,
            ),
            const SizedBox(width: 6),
            if (isSelected) // แสดงป้ายกำกับเฉพาะเมื่อรายการถูกเลือก
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}