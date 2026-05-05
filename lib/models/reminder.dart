class Reminder {
  final int id;
  final String title;
  final String description;
  final DateTime dateTime;

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.dateTime,
  });

  bool get isPast => dateTime.isBefore(DateTime.now());
}