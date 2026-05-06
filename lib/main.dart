import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = NotifyService();
  await service.init();
  runApp(MaterialApp(
    home: MainScreen(service: service),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
  ));
}

class Reminder {
  final int id;
  final String title;
  final String desc;
  final DateTime time;

  Reminder({required this.id, required this.title, required this.desc, required this.time});

  Map toJson() => {'id': id, 'title': title, 'desc': desc, 'time': time.toIso8601String()};
  factory Reminder.fromJson(Map json) => Reminder(
    id: json['id'], title: json['title'], desc: json['desc'], 
    time: DateTime.parse(json['time'])
  );
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

  void _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('reminders_db', jsonEncode(_list.map((e) => e.toJson()).toList()));
  }

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
        title: const Text("Напоминания"),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.blue), 
            onPressed: () => widget.service.showInstant()
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _list.length,
        itemBuilder: (context, index) {
          final item = _list[index];
          final isPast = item.time.isBefore(DateTime.now());
          return Card(
            color: isPast ? Colors.grey[200] : Colors.white,
            child: ListTile(
              title: Text(item.title, style: TextStyle(fontWeight: FontWeight.bold, decoration: isPast ? TextDecoration.lineThrough : null)),
              subtitle: Text("${item.desc}\n${DateFormat('dd.MM HH:mm').format(item.time)}"),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() async {
    final tCon = TextEditingController();
    final dCon = TextEditingController();
    DateTime selDate = DateTime.now();
    TimeOfDay selTime = TimeOfDay.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: tCon, decoration: const InputDecoration(labelText: 'Название')),
            TextField(controller: dCon, decoration: const InputDecoration(labelText: 'Описание')),
            Row(
              children: [
                TextButton(onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                  if (d != null) selDate = d;
                }, child: const Text("Дата")),
                TextButton(onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (t != null) selTime = t;
                }, child: const Text("Время")),
              ],
            ),
            ElevatedButton(onPressed: () {
              if (tCon.text.isNotEmpty) {
                final dt = DateTime(selDate.year, selDate.month, selDate.day, selTime.hour, selTime.minute);
                final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                setState(() => _list.add(Reminder(id: id, title: tCon.text, desc: dCon.text, time: dt)));
                _saveData();
                widget.service.schedule(id, tCon.text, dCon.text, dt);
                Navigator.pop(context);
              }
            }, child: const Text("Создать")),
          ],
        ),
      ),
    );
  }
}