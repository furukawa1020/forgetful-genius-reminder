
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  runApp(const SmartReminderApp());
}

class SmartReminderApp extends StatelessWidget {
  const SmartReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Reminder App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Task> tasks = [];
  List<Habit> habits = [];
  late SharedPreferences prefs;
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _initNotifications();
  }

  Future<void> _initPrefs() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      tasks = Task.decodeList(prefs.getStringList('tasks') ?? []);
      habits = Habit.decodeList(prefs.getStringList('habits') ?? []);
    });
  }

  Future<void> _initNotifications() async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings settings = InitializationSettings(android: androidSettings);
  await notificationsPlugin.initialize(settings);
  }

  Future<void> saveTasks() async {
    await prefs.setStringList('tasks', Task.encodeList(tasks));
  }

  Future<void> saveHabits() async {
    await prefs.setStringList('habits', Habit.encodeList(habits));
  }

  void addTask(Task task) {
    setState(() {
      tasks.add(task);
    });
    saveTasks();
    if (task.due != null) {
      _scheduleNotification(task);
    }
  }

  void removeTask(int index) {
    setState(() {
      tasks.removeAt(index);
    });
    saveTasks();
  }

  void addHabit(String name) {
    setState(() {
      habits.add(Habit(name: name));
    });
    saveHabits();
  }

  void markHabitDone(int index) {
    setState(() {
      habits[index].markDone();
    });
    saveHabits();
  }

  Future<void> _scheduleNotification(Task task) async {
    if (task.due == null) return;
    final tzDue = tz.TZDateTime.from(task.due!, tz.local);
    await notificationsPlugin.zonedSchedule(
      task.hashCode,
      'タスクの期限',
      task.title,
      tzDue,
      const NotificationDetails(android: AndroidNotificationDetails('reminder_channel', 'リマインダー')),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Reminder App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () async {
                final newTask = await Navigator.push<Task>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TaskCreationPage(),
                  ),
                );
                if (newTask != null) {
                  addTask(newTask);
                }
              },
              child: const Text('タスク追加'),
            ),
            const SizedBox(height: 10),
            Text('タスク一覧', style: Theme.of(context).textTheme.titleLarge),
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return ListTile(
                    title: Text(task.title),
                    subtitle: task.due != null ? Text('期限: ${task.due}') : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => removeTask(index),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            ElevatedButton(
              onPressed: () async {
                final newHabit = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HabitCreationPage(),
                  ),
                );
                if (newHabit != null && newHabit.isNotEmpty) {
                  addHabit(newHabit);
                }
              },
              child: const Text('習慣追加'),
            ),
            const SizedBox(height: 10),
            Text('習慣トラッキング', style: Theme.of(context).textTheme.titleLarge),
            Expanded(
              child: ListView.builder(
                itemCount: habits.length,
                itemBuilder: (context, index) {
                  final habit = habits[index];
                  return ListTile(
                    title: Text(habit.name),
                    subtitle: Text('達成回数: ${habit.doneCount}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () => markHabitDone(index),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskCreationPage extends StatefulWidget {
  const TaskCreationPage({super.key});

  @override
  State<TaskCreationPage> createState() => _TaskCreationPageState();
}

class _TaskCreationPageState extends State<TaskCreationPage> {
  final TextEditingController _controller = TextEditingController();
  DateTime? _due;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('タスク追加')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'タスク名'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(_due == null ? '期限未設定' : '期限: $_due'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _due = picked;
                      });
                    }
                  },
                  child: const Text('期限設定'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, Task(title: _controller.text, due: _due));
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }
}
class Task {
  final String title;
  final DateTime? due;

  Task({required this.title, this.due});

  Map<String, dynamic> toJson() => {
    'title': title,
    'due': due?.toIso8601String(),
  };

  static Task fromJson(Map<String, dynamic> json) => Task(
    title: json['title'],
    due: json['due'] != null ? DateTime.parse(json['due']) : null,
  );

  static List<Task> decodeList(List<String> list) =>
      list.map((e) => Task.fromJson(Map<String, dynamic>.from(_decode(e)))).toList();
  static List<String> encodeList(List<Task> list) =>
      list.map((e) => _encode(e.toJson())).toList();
}

// JSON encode/decode helpers
dynamic _decode(String s) => s.isNotEmpty ? (s.startsWith('{') ? Map<String, dynamic>.from(_parseJson(s)) : s) : null;
String _encode(dynamic v) => v is Map ? _toJson(v) : v.toString();
dynamic _parseJson(String s) => s.isNotEmpty ? (s.startsWith('{') ? _jsonDecode(s) : s) : null;
String _toJson(Map v) => v.toString().replaceAll("'", '"');
dynamic _jsonDecode(String s) => s.isNotEmpty ? (s.startsWith('{') ? Map<String, dynamic>.from(_jsonMap(s)) : s) : null;
dynamic _jsonMap(String s) => s.isNotEmpty ? Map<String, dynamic>.from(Uri.splitQueryString(s.replaceAll(RegExp('[{}"]'), ''))) : {};

class HabitCreationPage extends StatefulWidget {
  const HabitCreationPage({super.key});

  @override
  State<HabitCreationPage> createState() => _HabitCreationPageState();
}

class _HabitCreationPageState extends State<HabitCreationPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('習慣追加')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: '習慣名'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _controller.text);
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }
}

class Habit {
  final String name;
  int doneCount = 0;
  List<DateTime> history = [];

  Habit({required this.name});

  void markDone() {
    doneCount++;
    history.add(DateTime.now());
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'doneCount': doneCount,
    'history': history.map((e) => e.toIso8601String()).toList(),
  };

  static Habit fromJson(Map<String, dynamic> json) => Habit(name: json['name'])
    ..doneCount = json['doneCount'] ?? 0
    ..history = (json['history'] as List<dynamic>? ?? []).map((e) => DateTime.parse(e)).toList();

  static List<Habit> decodeList(List<String> list) =>
      list.map((e) => Habit.fromJson(Map<String, dynamic>.from(_decode(e)))).toList();
  static List<String> encodeList(List<Habit> list) =>
      list.map((e) => _encode(e.toJson())).toList();
}
