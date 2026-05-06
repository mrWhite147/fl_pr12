import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/reminder.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = NotifyService();
  await service.init();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
    home: MainScreen(service: service),
  ));
}

class MainScreen extends StatefulWidget {
  final NotifyService service;
  const MainScreen({super.key, required this.service});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Reminder> _list = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.service.requestPermissions();
  }

  // СОХРАНЕНИЕ В ПАМЯТЬ
  void _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('reminders_db', jsonEncode(_list.map((e) => e.toJson()).toList()));
  }

  // ЗАГРУЗКА ИЗ ПАМЯТИ
  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('reminders_db');
    if (raw != null) {
      setState(() => _list = (jsonDecode(raw) as List).map((e) => Reminder.fromJson(e)).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Мои Напоминания"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, color: Colors.orange), 
            onPressed: () => widget.service.showInstant()
          ),
        ],
      ),
      body: _list.isEmpty 
        ? const Center(child: Text("Список пуст"))
        : ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: _list.length,
            itemBuilder: (context, index) {
              final item = _list[index];
              final isPast = item.isPast;

              return Card(
                // ОФОРМЛЕНИЕ: Выделение прошедших серым цветом
                color: isPast ? Colors.grey[200] : Colors.white,
                elevation: isPast ? 0 : 3,
                child: ListTile(
                  leading: Icon(isPast ? Icons.check_circle_outline : Icons.alarm, color: isPast ? Colors.grey : Colors.deepPurple),
                  title: Text(
                    item.title, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      decoration: isPast ? TextDecoration.lineThrough : null, // Зачеркивание
                      color: isPast ? Colors.grey : Colors.black
                    )
                  ),
                  subtitle: Text("${item.desc}\n${DateFormat('dd.MM HH:mm').format(item.time)}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                    onPressed: () {
                      widget.service.cancel(item.id);
                      setState(() => _list.removeAt(index));
                      _saveData();
                    },
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        label: const Text("Добавить"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() {
    final tCon = TextEditingController();
    final dCon = TextEditingController();
    DateTime selDate = DateTime.now();
    TimeOfDay selTime = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Новое напоминание", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(controller: tCon, decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: dCon, decoration: const InputDecoration(labelText: 'Описание', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(icon: const Icon(Icons.calendar_month), label: const Text("Дата"), onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                  if (d != null) selDate = d;
                }),
                TextButton.icon(icon: const Icon(Icons.access_time), label: const Text("Время"), onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (t != null) selTime = t;
                }),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              onPressed: () {
                if (tCon.text.isNotEmpty) {
                  final dt = DateTime(selDate.year, selDate.month, selDate.day, selTime.hour, selTime.minute);
                  if (dt.isBefore(DateTime.now())) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Выберите время в будущем!")));
                    return;
                  }
                  final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                  setState(() {
                    _list.add(Reminder(id: id, title: tCon.text, desc: dCon.text, time: dt));
                    _list.sort((a, b) => a.time.compareTo(b.time)); // Сортировка
                  });
                  _saveData();
                  widget.service.schedule(id, tCon.text, dCon.text, dt);
                  Navigator.pop(context);
                }
              }, 
              child: const Text("СОЗДАТЬ")
            ),
          ],
        ),
      ),
    );
  }
}