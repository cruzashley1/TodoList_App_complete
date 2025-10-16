import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});
  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  DateTime? _dueDate;
  String _type = 'Minor';

  final CollectionReference _todosCollection =
  FirebaseFirestore.instance.collection('todos');

  @override
  void dispose() {
    _taskController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    if (_taskController.text.trim().isEmpty) {
      return;
    }

    try {
      await _todosCollection.add({
        'task': _taskController.text.trim(),
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'dueDate': _dueDate != null ? Timestamp.fromDate(_dueDate!) : null,
        'type': _type,
        'subject': _subjectController.text.trim(),
      });

      _taskController.clear();
      _subjectController.clear();
      setState(() {
        _dueDate = null;
        _type = 'Minor';
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Task added successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleTaskCompletion(String docId, bool currentStatus) async {
    try {
      await _todosCollection
          .doc(docId)
          .update({'completed': !currentStatus});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteTask(String docId) async {
    try {
      await _todosCollection.doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Task deleted!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _editTask(
      String docId,
      String currentTask,
      String currentSubject,
      DateTime? currentDueDate,
      String currentType,
      ) async {
    final controller = TextEditingController(text: currentTask);
    final subjectController = TextEditingController(text: currentSubject);
    DateTime? dueDate = currentDueDate;
    String type = currentType;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('Edit Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Task',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Due Date'),
                      subtitle: Text(dueDate != null
                          ? DateFormat.yMd().format(dueDate!)
                          : 'No due date'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          dialogSetState(() {
                            dueDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      value: type,
                      items: ['Minor', 'Major']
                          .map((e) =>
                          DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          dialogSetState(() {
                            type = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (controller.text.trim().isNotEmpty) {
                      try {
                        await _todosCollection.doc(docId).update({
                          'task': controller.text.trim(),
                          'subject': subjectController.text.trim(),
                          'dueDate': dueDate != null
                              ? Timestamp.fromDate(dueDate!)
                              : null,
                          'type': type,
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Task updated!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('MMM d, y').format(date);
  }

  String _formatDueDateField(Timestamp? dueTimestamp) {
    if (dueTimestamp == null) return 'No due date';
    final dt = dueTimestamp.toDate();
    return DateFormat.yMd().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My To-Do List'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input area
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      labelText: 'New Task',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add_task),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _addTask,
                  style:
                  ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Subject, Type, Due Date row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _type,
                  items: ['Minor', 'Major']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _type = value;
                      });
                    }
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _dueDate = picked;
                      });
                    }
                  },
                  child: const Text('Pick Due Date'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Task List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                _todosCollection.orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No tasks yet!',
                              style: TextStyle(fontSize: 18, color: Colors.grey)),
                          SizedBox(height: 8),
                          Text('Add a task to get started',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final task = data['task'] as String? ?? '';
                      final completed = data['completed'] as bool? ?? false;
                      final created = data['createdAt'] as Timestamp?;
                      final due = data['dueDate'] as Timestamp?;
                      final subject = data['subject'] as String? ?? '';
                      final type = data['type'] as String? ?? '';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        child: ListTile(
                          leading: Checkbox(
                            value: completed,
                            onChanged: (_) =>
                                _toggleTaskCompletion(doc.id, completed),
                          ),
                          title: Text(
                            task,
                            style: TextStyle(
                              decoration:
                              completed ? TextDecoration.lineThrough : null,
                              color: completed ? Colors.grey : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (subject.isNotEmpty) Text('Subject: $subject'),
                              if (type.isNotEmpty) Text('Type: $type'),
                              Text('Due: ${_formatDueDateField(due)}'),
                              if (created != null)
                                Text(
                                  'Added: ${_formatTimestamp(created)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _editTask(
                                  doc.id,
                                  task,
                                  subject,
                                  due?.toDate(),
                                  type,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red, size: 20),
                                onPressed: () => _deleteTask(doc.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
