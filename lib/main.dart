import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/reminder.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await NotificationService().init();
  
  runApp(const MaterialApp(
    home: HomeScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Reminder> _reminders = [];
  final _notificationService = NotificationService();
  bool _isPermissionGranted = true;

  @override
  void initState() {
    super.initState();
    _handlePermissions();
  }

  Future<void> _handlePermissions() async {
    bool granted = await _notificationService.requestPermissions();
    
    var status = await Permission.notification.status;
    
    setState(() {
      _isPermissionGranted = status.isGranted;
    });
  }

  void _addReminder(String title, String desc, DateTime dt) {
    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    final newReminder = Reminder(
      id: id,
      title: title,
      description: desc,
      dateTime: dt,
    );

    setState(() {
      _reminders.add(newReminder);
      _reminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    });

    _notificationService.scheduleNotification(
      id: id,
      title: title,
      body: desc,
      scheduledDate: dt,
    );
  }
  void _deleteReminder(int id) {
    setState(() {
      _reminders.removeWhere((r) => r.id == id);
    });
    _notificationService.cancelNotification(id);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Напоминание удалено')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Напоминалка'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => _notificationService.showInstantNotification(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isPermissionGranted)
            Container(
              width: double.infinity,
              color: Colors.amber[100],
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Уведомления отключены! Вы не получите напоминания вовремя.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('ВКЛЮЧИТЬ'),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: _reminders.isEmpty
                ? const Center(child: Text('Напоминаний пока нет'))
                : ListView.builder(
                    itemCount: _reminders.length,
                    padding: const EdgeInsets.all(10),
                    itemBuilder: (context, index) {
                      final item = _reminders[index];
                      final bool isPast = item.isPast;

                      return Card(
                        color: isPast ? Colors.grey[200] : Colors.white,
                        elevation: isPast ? 0 : 3,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Icon(
                            isPast ? Icons.history : Icons.alarm,
                            color: isPast ? Colors.grey : Colors.blue,
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: isPast ? TextDecoration.lineThrough : null,
                              color: isPast ? Colors.grey : Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            '${item.description}\n${DateFormat('dd.MM.yyyy HH:mm').format(item.dateTime)}',
                            style: TextStyle(color: isPast ? Colors.grey : Colors.black87),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteReminder(item.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Новое напоминание', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Название напоминания')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Описание')),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Дата'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) selectedDate = d;
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: const Text('Время'),
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (t != null) selectedTime = t;
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final finalDateTime = DateTime(
                  selectedDate.year, selectedDate.month, selectedDate.day,
                  selectedTime.hour, selectedTime.minute,
                );
                
                if (titleController.text.isEmpty) return;
                
                if (finalDateTime.isAfter(DateTime.now())) {
                  _addReminder(titleController.text, descController.text, finalDateTime);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Выберите время в будущем!')),
                  );
                }
              },
              child: const Text('СОХРАНИТЬ'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}