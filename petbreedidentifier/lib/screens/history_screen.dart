import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'history_detail_screen.dart';
import '../services/db_helper.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController; // ตัวควบคุมแท็บ
  List<Map<String, dynamic>> _historyItems = []; // รายการประวัติทั้งหมด

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // สร้างตัวควบคุมแท็บ
    _loadHistory(); // โหลดประวัติจากฐานข้อมูล
  }

  // โหลดประวัติจากฐานข้อมูล
  Future<void> _loadHistory() async {
    final data = await DBHelper.getAllHistory();
    setState(() {
      _historyItems = data;
    });
  }

  // ลบประวัติทั้งหมดตามประเภท
  Future<void> _deleteAll(String type) async {
    final db = await DBHelper.database;
    final items = _getItemsByType(type);
    for (var item in items) {
      await db.delete(
        'pets_history',
        where: 'id = ?',
        whereArgs: [item['id']],
      );
    }
    _loadHistory();
  }

  // ลบรายการประวัติทีละรายการ
  Future<void> _deleteItem(int id) async {
    await DBHelper.deleteHistory(id);
    _loadHistory();
  }

  // ดึงรายการประวัติตามประเภท
  List<Map<String, dynamic>> _getItemsByType(String type) {
    return _historyItems.where((item) {
      if (item['breeds'] == null) return false;
      List<Map<String, dynamic>> breedsJson = [];
      try {
        breedsJson =
            List<Map<String, dynamic>>.from(jsonDecode(item['breeds'] ?? '[]'));
      } catch (_) {}
      return breedsJson.any((b) => (b['species'] ?? '').toString() == type);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFA726),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCE8426),
        title: const Text("ประวัติ", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final type = _tabController.index == 0 ? 'dog' : 'cat';
              final items = _getItemsByType(type);
              if (items.isEmpty) return; // ถ้าไม่มีรายการไม่ต้องลบ

              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('ลบประวัติ${type == 'dog' ? 'สุนัข' : 'แมว'}ทั้งหมด?'),
                  content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบทั้งหมด?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('ยกเลิก'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('ลบ', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                _deleteAll(type);
              }
            },
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Container(
            color: const Color(0xFFCE8426),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFFFFCC80),
              ),
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              tabs: const [
                Tab(child: Align(alignment: Alignment.center, child: Text('สุนัข'))),
                Tab(child: Align(alignment: Alignment.center, child: Text('แมว'))),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryList("dog"),
          _buildHistoryList("cat"),
        ],
      ),
    );
  }

  // สร้างรายการประวัติ
  Widget _buildHistoryList(String type) {
    final items = _getItemsByType(type);

    if (items.isEmpty) {
      return Center(
        child: Text(
          "ไม่มีประวัติ ${type == 'dog' ? 'สุนัข' : 'แมว'}",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index]; // รายการประวัติแต่ละรายการ
        final id = item['id'] as int; // รหัสรายการ
        final date = DateFormat('yyyy-MM-dd').format(
            DateTime.tryParse(item['datetime'] ?? '') ?? DateTime.now());

        final imagePath = item['originalImage'] ?? item['boxedImage'] ?? '';

        IconData speciesIcon = type == 'dog' ? Icons.pets : Icons.pets_outlined;
        Color iconColor = type == 'dog' ? Colors.brown : Colors.deepOrange;

        // สร้างรายการที่สามารถปัดเพื่อลบได้
        return Dismissible(
          key: ValueKey(id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('ยืนยันการลบ'),
                content: const Text('คุณต้องการลบรายการนี้หรือไม่?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('ยกเลิก'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('ลบ', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) {
            _deleteItem(id);
          },
          // แสดงพื้นหลังเมื่อเลื่อนรายการ
          background: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Icon(Icons.delete_forever, color: Colors.white, size: 28),
                    SizedBox(width: 8), 
                    Text('ลบ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () {
                // ไปยังหน้ารายละเอียดประวัติ ถ้าแตะรายการ จะ push ไปที่ HistoryDetailScreen(item: item)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistoryDetailScreen(item: item),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // รูปวงกลมใหญ่
                    ClipOval(
                      child: (imagePath.isNotEmpty && File(imagePath).existsSync())
                          ? Image.file(
                              File(imagePath),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[300],
                              child: Icon(Icons.pets, size: 50, color: Colors.white),
                            ),
                    ),
                    const SizedBox(width: 20),
                    // วันที่ + icon species
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            date,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(speciesIcon, color: iconColor, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                type == 'dog' ? 'สุนัข' : 'แมว',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // ลูกศรชี้ขวา
                    const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}