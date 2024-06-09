import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:table_calendar/table_calendar.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMonthNotes();
  }

  void _loadMonthNotes() {
    final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    DatabaseReference ref = FirebaseDatabase.instance.ref(
        'notes/${_focusedDay.year}/${_focusedDay.month.toString().padLeft(2, '0')}');
    ref.once().then((DatabaseEvent event) {
      Map<dynamic, dynamic>? data =
          event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        _datesWithNotes.clear(); // Clear existing notes before adding new ones
        data.forEach((key, value) {
          int day = int.parse(key);
          DateTime date = DateTime(_focusedDay.year, _focusedDay.month, day);
          if (date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
              date.isBefore(endOfMonth.add(const Duration(days: 1))) &&
              value != null &&
              value['note'].toString().isNotEmpty) {
            _datesWithNotes.add(date);
          }
        });
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Map<String, String> formatDateTime(DateTime dateTime) {
    return {
      'year': dateTime.year.toString(),
      'month': dateTime.month.toString().padLeft(2, '0'),
      'day': dateTime.day.toString().padLeft(2, '0')
    };
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
      if (text.isEmpty) {
        _datesWithNotes.remove(_selectedDay);
      } else {
        _datesWithNotes.add(DateTime(
            _selectedDay!.year, _selectedDay!.month, _selectedDay!.day));
      }
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note updated successfully')));
      setState(() {});
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update note: $error')));
    });
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
                            color: Colors.red,
                            fontWeight: FontWeight
                                .bold), // Red text for days with notes
                      ),
                    );
                  }
                  return Center(
                    child: Text(day.day.toString(),
                        style: TextStyle(
                            fontWeight: FontWeight
                                .bold)), // Default appearance for days without notes
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
