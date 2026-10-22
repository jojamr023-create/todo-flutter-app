import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TodoApp());
}

const Color appPurple = Color(0xFF6C63FF);

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ToDo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: appPurple),
        scaffoldBackgroundColor: const Color(0xFFF8F7FC),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const TodoHomePage(),
    );
  }
}

class TodoTask {
  TodoTask({
    required this.id,
    required this.title,
    this.note = '',
    this.isDone = false,
    this.priority = 'Medium',
    this.dueDate,
  });

  final String id;
  String title;
  String note;
  bool isDone;
  String priority;
  DateTime? dueDate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'isDone': isDone,
        'priority': priority,
        'dueDate': dueDate?.toIso8601String(),
      };

  factory TodoTask.fromJson(Map<String, dynamic> json) => TodoTask(
        id: json['id'] as String,
        title: json['title'] as String,
        note: (json['note'] as String?) ?? '',
        isDone: (json['isDone'] as bool?) ?? false,
        priority: (json['priority'] as String?) ?? 'Medium',
        dueDate: json['dueDate'] == null
            ? null
            : DateTime.tryParse(json['dueDate'] as String),
      );
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  static const String storageKey = 'todo_tasks_v1';
  final TextEditingController searchController = TextEditingController();
  List<TodoTask> tasks = [];
  String activeFilter = 'All';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTasks();
    searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTasks = prefs.getString(storageKey);
    if (savedTasks != null) {
      try {
        final decoded = jsonDecode(savedTasks) as List<dynamic>;
        tasks = decoded
            .map((item) => TodoTask.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        tasks = [];
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
  }

  List<TodoTask> get visibleTasks {
    final query = searchController.text.trim().toLowerCase();
    return tasks.where((task) {
      final matchesSearch = task.title.toLowerCase().contains(query) ||
          task.note.toLowerCase().contains(query);
      final matchesFilter = switch (activeFilter) {
        'Today' => task.dueDate != null && _isSameDay(task.dueDate!, DateTime.now()),
        'Important' => task.priority == 'High',
        'Completed' => task.isDone,
        'Pending' => !task.isDone,
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        if (a.dueDate == null && b.dueDate != null) return 1;
        if (a.dueDate != null && b.dueDate == null) return -1;
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        }
        return 0;
      });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int get completedCount => tasks.where((task) => task.isDone).length;
  int get pendingCount => tasks.where((task) => !task.isDone).length;

  Future<void> openTaskEditor({TodoTask? task}) async {
    final result = await showDialog<TodoTask>(
      context: context,
      builder: (_) => TaskEditorDialog(task: task),
    );
    if (result == null) return;

    setState(() {
      final index = tasks.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        tasks.add(result);
      } else {
        tasks[index] = result;
      }
    });
    await saveTasks();
  }

  Future<void> toggleTask(TodoTask task, bool value) async {
    setState(() => task.isDone = value);
    await saveTasks();
  }

  Future<void> deleteTask(TodoTask task) async {
    setState(() => tasks.removeWhere((item) => item.id == task.id));
    await saveTasks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${task.title}" deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            setState(() => tasks.add(task));
            await saveTasks();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shownTasks = visibleTasks;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F7FC),
        title: const Text('ToDo', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Clear completed tasks',
            onPressed: tasks.any((task) => task.isDone) ? clearCompleted : null,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$pendingCount task${pendingCount == 1 ? '' : 's'} left · $completedCount completed',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search tasks...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: searchController.clear,
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final filter in [
                                'All',
                                'Today',
                                'Important',
                                'Pending',
                                'Completed',
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(filter),
                                    selected: activeFilter == filter,
                                    onSelected: (_) => setState(() => activeFilter = filter),
                                    selectedColor: appPurple.withOpacity(0.16),
                                    side: BorderSide(
                                      color: activeFilter == filter
                                          ? appPurple
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: shownTasks.isEmpty
                        ? _EmptyState(
                            hasTasks: tasks.isNotEmpty,
                            onAdd: () => openTaskEditor(),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            itemCount: shownTasks.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final task = shownTasks[index];
                              return _TaskCard(
                                task: task,
                                onToggle: (value) => toggleTask(task, value),
                                onEdit: () => openTaskEditor(task: task),
                                onDelete: () => deleteTask(task),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openTaskEditor(),
        backgroundColor: appPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning!';
    if (hour < 18) return 'Good afternoon!';
    return 'Good evening!';
  }

  Future<void> clearCompleted() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear completed tasks?'),
        content: const Text('This will remove all completed tasks from your list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (shouldClear != true) return;
    setState(() => tasks.removeWhere((task) => task.isDone));
    await saveTasks();
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final TodoTask task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (task.priority) {
      'High' => Colors.red,
      'Low' => Colors.green,
      _ => Colors.orange,
    };

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: task.isDone,
              activeColor: appPurple,
              shape: const CircleBorder(),
              onChanged: (value) => onToggle(value ?? false),
            ),
            Expanded(
              child: InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                          color: task.isDone ? Colors.grey : Colors.black87,
                        ),
                      ),
                      if (task.note.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (task.dueDate != null)
                            Text(
                              _formatDate(task.dueDate!),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: priorityColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              task.priority,
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class TaskEditorDialog extends StatefulWidget {
  const TaskEditorDialog({super.key, this.task});

  final TodoTask? task;

  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController noteController;
  late String priority;
  DateTime? dueDate;

  bool get isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.task?.title ?? '');
    noteController = TextEditingController(text: widget.task?.note ?? '');
    priority = widget.task?.priority ?? 'Medium';
    dueDate = widget.task?.dueDate;
  }

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit task' : 'Create a task'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Task title *',
                  hintText: 'e.g. Study Dart',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'Low', child: Text('Low')),
                  DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'High', child: Text('High')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => priority = value);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(dueDate == null ? 'No due date' : _formatDate(dueDate!)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: chooseDate,
              ),
              if (dueDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => dueDate = null),
                    child: const Text('Remove date'),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: save,
          child: Text(isEditing ? 'Save changes' : 'Add task'),
        ),
      ],
    );
  }

  Future<void> chooseDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 10),
    );
    if (picked != null) setState(() => dueDate = picked);
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final oldTask = widget.task;
    final result = TodoTask(
      id: oldTask?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: titleController.text.trim(),
      note: noteController.text.trim(),
      isDone: oldTask?.isDone ?? false,
      priority: priority,
      dueDate: dueDate,
    );
    Navigator.pop(context, result);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasTasks, required this.onAdd});

  final bool hasTasks;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: appPurple.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.checklist_rounded, size: 54, color: appPurple),
            ),
            const SizedBox(height: 20),
            Text(
              hasTasks ? 'No matching tasks' : 'Nothing on your list yet',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasTasks
                  ? 'Try another filter or search term.'
                  : 'Add your first task and take one small step forward.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (!hasTasks) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Create first task'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
