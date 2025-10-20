import 'package:flutter/material.dart';
import 'breed_detail_screen.dart';
import '../services/pet_service.dart';
import '../models/pet_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// เป็นเหมือน "ผู้จัดการ" ที่คอยเก็บข้อความที่ผู้ใช้พิมพ์ในช่องค้นหา
  final TextEditingController _searchController = TextEditingController();
  List<Pet> allBreeds = [];  // รายการสายพันธุ์ทั้งหมด
  List<Pet> filteredBreeds = [];  // รายการสายพันธุ์ที่กรองแล้ว

  /// ฟังก์ชันที่ทำงานเมื่อหน้าจอถูกสร้างขึ้นครั้งแรก
  @override
  void initState() {
    super.initState();
    _loadBreeds(); // โหลดข้อมูลสายพันธุ์
    _searchController.addListener(_filterBreeds); // ตั้งค่าการฟังการเปลี่ยนแปลงในช่องค้นหา
  }

  /// ฟังก์ชันที่โหลดข้อมูลสายพันธุ์
  Future<void> _loadBreeds() async {
    /// ดึงข้อมูลสายพันธุ์จาก PetService
    final breeds = await PetService.getAllBreeds();
    setState(() {
      allBreeds = breeds; // เก็บข้อมูลสายพันธุ์ทั้งหมด
      filteredBreeds = breeds; // เริ่มต้นรายการกรองด้วยข้อมูลทั้งหมด
    });
  }

  /// ฟังก์ชันที่กรองสายพันธุ์ตามข้อความในช่องค้นหา
  void _filterBreeds() {
    /// ดึงข้อความจากช่องค้นหาและแปลงเป็นตัวพิมพ์เล็ก
    final query = _searchController.text.toLowerCase();
    setState(() { // อัปเดตรายการกรอง
      filteredBreeds = allBreeds  // กรองสายพันธุ์ที่ตรงกับข้อความค้นหา
          /// ตรวจสอบว่าชื่อสายพันธุ์มีข้อความค้นหาอยู่หรือไม่ 
          .where((breed) => breed.name.toLowerCase().contains(query))
          .toList(); // แปลงผลลัพธ์เป็นรายการ
    });
  }

  @override
  void dispose() {
    _searchController.dispose();  // ปล่อยทรัพยากรของตัวควบคุมเมื่อไม่ใช้งานแล้ว
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // สร้าง "กรอบหน้าจอ" หลัก พื้นหลังเป็นสีส้มสดใส (0xFFFFA726)
      backgroundColor: const Color(0xFFFFA726),
      appBar: AppBar( // สร้าง "แถบด้านบน" (AppBar) มีสีส้มเข้มขึ้น (0xFFCE8426)
        backgroundColor: const Color(0xFFCE8426),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'ข้อมูลสายพันธุ์',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column( // ใช้ Column เพื่อจัดวางองค์ประกอบในแนวตั้ง (ช่องค้นหาและรายการสายพันธุ์)
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อสายพันธุ์',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded( // ส่วนนี้คือ "พื้นที่แสดงรายการ" ที่ขยายออกไปเต็มพื้นที่ที่เหลือทั้งหมด
            child: allBreeds.isEmpty
                ? const Center(child: CircularProgressIndicator()) /// แสดงวงกลมโหลดข้อมูลถ้ายังไม่มีข้อมูล
                : filteredBreeds.isEmpty /// ถ้าไม่มีสายพันธุ์ที่ตรงกับการค้นหา แสดงข้อความ "ไม่พบสายพันธุ์"
                    ? const Center(
                        child: Text(
                          'ไม่พบสายพันธุ์',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      )
                    : ListView.builder( // สร้างรายการสายพันธุ์ที่กรองแล้ว
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filteredBreeds.length,
                        itemBuilder: (context, index) { /// สร้างแต่ละรายการใน ListView
                          final breed = filteredBreeds[index];
                          return Card( // ใช้ Card เพื่อให้แต่ละรายการมีลักษณะเหมือนการ์ด
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(  // แสดงรูปภาพสายพันธุ์ในวงกลม
                                backgroundImage: AssetImage(breed.imageAsset),
                                radius: 20,
                              ),
                              title: Text( // แสดงชื่อสายพันธุ์
                                breed.name,
                                style: const TextStyle(fontSize: 16),
                              ),
                              onTap: () { // เมื่อแตะที่รายการ ให้ไปยังหน้ารายละเอียดสายพันธุ์
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BreedDetailScreen(pet: breed),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}