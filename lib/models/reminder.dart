import 'dart:convert';

class Reminder {
  final int id;
  final String title;
  final String desc;
  final DateTime time;

  Reminder({required this.id, required this.title, required this.desc, required this.time});

  bool get isPast => time.isBefore(DateTime.now());

  Map toJson() => {
    'id': id, 
    'title': title, 
    'desc': desc, 
    'time': time.toIso8601String()
  };

  factory Reminder.fromJson(Map json) => Reminder(
    id: json['id'], 
    title: json['title'], 
    desc: json['desc'], 
    time: DateTime.parse(json['time'])
  );
}