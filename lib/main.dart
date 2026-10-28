import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Replace with your computer's LAN IP.
// Do not use localhost on a physical Android phone.
const String apiBase = 'http://192.168.1.10:8000';
const bool useMockData = true;

void main() {
  runApp(const MedicineApp());
}

// Include the local UTC offset in the timestamp sent to FastAPI.
String isoWithOffset(DateTime dateTime) {
  final offset = dateTime.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inMinutes.abs() ~/ 60;
  final minutes = offset.inMinutes.abs() % 60;

  final base = dateTime.toIso8601String();

  return '$base$sign'
      '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
}

class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Medicine Monitor',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
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
  List<dynamic> schedules = [];
  List<dynamic> events = [];

  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    refreshAll();
  }

  Future<void> refreshAll() async {
        if (useMockData) {
      setState(() {
        error = null;
        if (schedules.isEmpty) {
          schedules = [
            {
              'id': 1,
              'medicine_name': 'Paracetamol',
              'cartridge_id': 1,
              'dose_label': '1 tablet',
              'scheduled_at': '2026-10-28 20:00',
              'active': true,
            },
            {
              'id': 2,
              'medicine_name': 'Vitamin D',
              'cartridge_id': 2,
              'dose_label': '1 capsule',
              'scheduled_at': '2026-10-29 08:00',
              'active': true,
            },
          ];
          events = [
            {
              'event_type': 'dispensed',
              'created_at': '2026-10-28 08:00',
              'details': 'Cartridge 2 opened',
            },
            {
              'event_type': 'pickup_detected',
              'created_at': '2026-10-28 08:01',
              'details': 'Tray sensor triggered',
            },
          ];
        }
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$apiBase/api/schedules'))
            .timeout(const Duration(seconds: 5)),
        http.get(Uri.parse('$apiBase/api/events?limit=50'))
            .timeout(const Duration(seconds: 5)),
      ]);

      if (responses.any((r) => r.statusCode != 200)) {
        throw Exception('Backend API returned an error.');
      }

      if (!mounted) return;

      setState(() {
        schedules =
            jsonDecode(responses[0].body) as List<dynamic>;
        events =
            jsonDecode(responses[1].body) as List<dynamic>;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Cannot connect to backend: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> addSchedule() async {
    final nameController = TextEditingController();
    final doseController =
        TextEditingController(text: '1 dose');

    int cartridgeId = 1;
    DateTime selected =
        DateTime.now().add(const Duration(minutes: 5));

    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add medicine schedule'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Medicine name',
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Enter medicine name';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: doseController,
                    decoration: const InputDecoration(
                      labelText: 'Dose description',
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    value: cartridgeId,
                    decoration: const InputDecoration(
                      labelText: 'Medicine cartridge',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 1,
                        child: Text('Cartridge 1'),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Text('Cartridge 2'),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text('Cartridge 3'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        cartridgeId = value ?? 1;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('Scheduled: ${selected.toLocal()}'),
                  OutlinedButton(
                    child: const Text('Choose date and time'),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selected,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 1)),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                      );

                      if (date == null ||
                          !context.mounted) {
                        return;
                      }

                      final time = await showTimePicker(
                        context: context,
                        initialTime:
                            TimeOfDay.fromDateTime(selected),
                      );

                      if (time == null) return;

                      setDialogState(() {
                        selected = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) {
      nameController.dispose();
      doseController.dispose();
      return;
    }
        if (useMockData) {
      setState(() {
        schedules.add({
          'id': schedules.length + 1,
          'medicine_name': nameController.text.trim(),
          'cartridge_id': cartridgeId,
          'dose_label': doseController.text.trim().isEmpty
              ? '1 dose'
              : doseController.text.trim(),
          'scheduled_at': selected.toString(),
          'active': true,
        });
      });
      nameController.dispose();
      doseController.dispose();
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiBase/api/schedules'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'medicine_name': nameController.text.trim(),
          'cartridge_id': cartridgeId,
          'dose_label': doseController.text.trim().isEmpty
              ? '1 dose'
              : doseController.text.trim(),
          'scheduled_at': isoWithOffset(selected),
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(response.body);
      }

      await refreshAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      nameController.dispose();
      doseController.dispose();
    }
  }

  Future<void> setActive(int id, bool active) async {
        if (useMockData) {
      setState(() {
        for (final s in schedules) {
          if (s['id'] == id) s['active'] = active;
        }
      });
      return;
    }
    try {
      final response = await http.patch(
        Uri.parse(
          '$apiBase/api/schedules/$id/active?active=$active',
        ),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(response.body);
      }

      await refreshAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Medicine Monitor'),
        actions: [
          IconButton(
            onPressed: refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addSchedule,
        icon: const Icon(Icons.add),
        label: const Text('Add schedule'),
      ),
      body: RefreshIndicator(
        onRefresh: refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device dashboard',
                      style:
                          Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(loading
                        ? 'Refreshing...'
                        : 'Schedules: ${schedules.length} '
                          '• Events: ${events.length}'),
                    if (error != null)
                      Text(
                        error!,
                        style:
                            const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sensor events do not prove that '
                      'medicine was swallowed.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Medication schedules',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (schedules.isEmpty)
              const ListTile(
                title: Text('No schedules added'),
              ),
            ...schedules.map((schedule) {
              final active = schedule['active'] == true;

              return Card(
                child: SwitchListTile(
                  value: active,
                  onChanged: (value) => setActive(
                    schedule['id'] as int,
                    value,
                  ),
                  title: Text(
                    '${schedule['medicine_name']} '
                    '— Cartridge ${schedule['cartridge_id']}',
                  ),
                  subtitle: Text(
                    '${schedule['dose_label']}\n'
                    '${schedule['scheduled_at']}',
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Text(
              'Recent device events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (events.isEmpty)
              const ListTile(
                title: Text('No device events received'),
              ),
            ...events.map((event) => ListTile(
              leading: const Icon(Icons.sensors),
              title: Text('${event['event_type']}'),
              subtitle: Text(
                '${event['created_at']}\n'
                '${event['details'] ?? ''}',
              ),
              isThreeLine: true,
            )),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}