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
      title: 'Flutter Calendar Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Calendar Demo Home Page'),
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
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // Helper function to format dates into parts
  Map<String, String> formatDateTime(DateTime dateTime) {
    return {
      'year': dateTime.year.toString(),
      'month': dateTime.month.toString().padLeft(2, '0'),
      'day': dateTime.day.toString().padLeft(2, '0')
    };
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    var dateParts = formatDateTime(selectedDay);
    DatabaseReference ref = FirebaseDatabase.instance.ref(
        'notes/${dateParts['year']}/${dateParts['month']}/${dateParts['day']}');
    DatabaseEvent event = await ref.once();

    Map<dynamic, dynamic>? data =
        event.snapshot.value as Map<dynamic, dynamic>?;
    setState(() {
      _noteController.text = data?['note'] ?? '';
    });
  }

  void _saveNote() async {
    final text = _noteController.text;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No note to save')));
      return;
    }

    var dateParts = formatDateTime(_selectedDay);
    DatabaseReference ref = FirebaseDatabase.instance.ref(
        'notes/${dateParts['year']}/${dateParts['month']}/${dateParts['day']}');

    await ref.set({
      'date': '${dateParts['year']}-${dateParts['month']}-${dateParts['day']}',
      'note': text,
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved successfully')));
    }).catchError((error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save note: $error')));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
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
    );
  }
}
