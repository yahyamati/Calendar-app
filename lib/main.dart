import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ladjeroud Calendar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          color: Colors.grey[850], // Dark grey for the AppBar in light theme
          foregroundColor: Colors.white, // Ensures icons and text are visible
          elevation: 0, // Removes shadow for a flatter appearance
        ),
        primarySwatch: Colors.grey,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        appBarTheme: AppBarTheme(
          color: Colors
              .grey[900], // Even darker shade for the AppBar in dark theme
          foregroundColor: Colors.white, // Ensures icons and text are visible
          elevation: 0, // Removes shadow for a flatter appearance
        ),
        primarySwatch: Colors.grey,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MyHomePage(title: 'Ladjeroud Calendar'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();
  TextEditingController _noteController = TextEditingController();
  Set<DateTime> _datesWithNotes = {};

  late FlutterLocalNotificationsPlugin localNotificationsPlugin;
  String _lastNote = ''; // Track the last note to compare with the new note

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadMonthNotes();
  }

  void _initializeNotifications() {
    localNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );
    localNotificationsPlugin.initialize(initializationSettings);
  }

  void _loadMonthNotes() {
    final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    DatabaseReference ref = FirebaseDatabase.instance.ref(
        'notes/${_focusedDay.year}/${_focusedDay.month.toString().padLeft(2, '0')}');
    ref.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      _datesWithNotes.clear(); // Clear existing notes before adding new ones
      data.forEach((key, value) {
        int day = int.parse(key);
        DateTime date = DateTime(_focusedDay.year, _focusedDay.month, day);
        if (date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            date.isBefore(endOfMonth.add(const Duration(days: 1))) &&
            value['note'].toString().isNotEmpty) {
          _datesWithNotes.add(date);
          _showNotification(value['note']); // Show notification on new note
        }
      });
      setState(() {});
    });
  }

  Future<void> _showNotification(String noteText) async {
    if (noteText != _lastNote) {
      // Check if the note is different from the last note
      _lastNote = noteText; // Update the last note with the new note
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'note_id', // This is the channel ID
        'New Note', // This is the channel name
        channelDescription:
            'Notification for new note added', // This needs to be a named argument
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);
      await localNotificationsPlugin.show(
        0, // Notification ID
        'New Note Added', // Title of the notification
        noteText, // Body of the notification
        platformChannelSpecifics, // This should be a named argument
      );
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    var dateParts = formatDateTime(selectedDay);
    DatabaseReference ref = FirebaseDatabase.instance.ref(
        'notes/${dateParts['year']}/${dateParts['month']}/${dateParts['day']}');
    ref.once().then((DatabaseEvent event) {
      Map<dynamic, dynamic>? data =
          event.snapshot.value as Map<dynamic, dynamic>?;
      setState(() {
        _noteController.text = data?['note'] ?? '';
        if (data != null && data['note'].toString().isEmpty) {
          _datesWithNotes.remove(
              DateTime(selectedDay.year, selectedDay.month, selectedDay.day));
        } else if (data != null && data['note'].toString().isNotEmpty) {
          _datesWithNotes.add(
              DateTime(selectedDay.year, selectedDay.month, selectedDay.day));
        }
      });
    });
  }

  void _saveNote() async {
    final text = _noteController.text.trim();
    var dateParts = formatDateTime(_selectedDay!);

    DatabaseReference ref = FirebaseDatabase.instance.ref(
        'notes/${dateParts['year']}/${dateParts['month']}/${dateParts['day']}');

    await ref.set({
      'date': '${dateParts['year']}-${dateParts['month']}-${dateParts['day']}',
      'note': text,
    }).then((_) {
      _lastNote = text; // Update the last saved note
      // Other existing code
    }).catchError((error) {
      // Other existing code
    });
  }

  Map<String, String> formatDateTime(DateTime dateTime) {
    return {
      'year': dateTime.year.toString(),
      'month': dateTime.month.toString().padLeft(2, '0'),
      'day': dateTime.day.toString().padLeft(2, '0')
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedDay = null; // Deselect the current day
            _noteController.text = ''; // Clear the text field
          });
          _loadMonthNotes(); // Reload to update the calendar view
        },
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2010, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) =>
                  _selectedDay != null && isSameDay(_selectedDay!, day),
              onDaySelected: _onDaySelected,
              onPageChanged: (focusedDay) {
                if (focusedDay.month != _focusedDay.month ||
                    focusedDay.year != _focusedDay.year) {
                  _focusedDay = focusedDay;
                  _loadMonthNotes(); // Fetch notes for the new month
                }
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  if (_datesWithNotes
                      .contains(DateTime(day.year, day.month, day.day))) {
                    return Container(
                      margin: const EdgeInsets.all(4.0),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors
                            .blue[200], // Background color for days with notes
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        day.day.toString(),
                        style: TextStyle(
                            color: Colors.red, // Red text for days with notes
                            fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                  return Center(
                    child: Text(day.day.toString(),
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  return Center(
                    child: Text(
                      day.day.toString(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Write a note',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _saveNote,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
