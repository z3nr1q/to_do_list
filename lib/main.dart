import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

enum FilterType {
  all,
  pending,
  completed,
  today,
  overdue,
}

enum SortType {
  priority,
  dueDate,
  category,
  status,
}

enum Priority {
  high,
  medium,
  low,
}

extension PriorityExtension on Priority {
  String get name {
    switch (this) {
      case Priority.high:
        return 'Alta';
      case Priority.medium:
        return 'Média';
      case Priority.low:
        return 'Baixa';
    }
  }

  Color get color {
    switch (this) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.orange;
      case Priority.low:
        return Colors.green;
    }
  }

  IconData get icon {
    switch (this) {
      case Priority.high:
        return Icons.priority_high;
      case Priority.medium:
        return Icons.remove;
      case Priority.low:
        return Icons.arrow_downward;
    }
  }
}

class Category {
  final String name;
  final Color color;

  const Category({required this.name, required this.color});

  Map<String, dynamic> toJson() => {
    'name': name,
    'color': color.value,
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    name: json['name'],
    color: Color(json['color']),
  );
}

class Subtask {
  String text;
  bool isDone;

  Subtask({
    required this.text,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isDone': isDone,
  };

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
    text: json['text'],
    isDone: json['isDone'],
  );
}

class Todo {
  String text;
  bool isDone;
  Category category;
  DateTime? dueDate;
  Priority priority;
  List<Subtask> subtasks;

  Todo({
    required this.text,
    this.isDone = false,
    required this.category,
    this.dueDate,
    this.priority = Priority.medium,
    List<Subtask>? subtasks,
  }) : subtasks = subtasks ?? [];

  double get progress {
    if (subtasks.isEmpty) return isDone ? 1.0 : 0.0;
    return subtasks.where((subtask) => subtask.isDone).length / subtasks.length;
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'isDone': isDone,
    'category': category.toJson(),
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority.index,
    'subtasks': subtasks.map((subtask) => subtask.toJson()).toList(),
  };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    text: json['text'],
    isDone: json['isDone'],
    category: Category.fromJson(json['category']),
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    priority: Priority.values[json['priority'] ?? Priority.medium.index],
    subtasks: (json['subtasks'] as List?)
        ?.map((e) => Subtask.fromJson(e))
        .toList() ?? [],
  );

  String get dueDateText {
    if (dueDate == null) return 'Sem data';
    
    final now = DateTime.now();
    final difference = dueDate!.difference(now);
    
    if (difference.isNegative) {
      return 'Atrasada';
    } else if (difference.inDays == 0) {
      return 'Hoje';
    } else if (difference.inDays == 1) {
      return 'Amanhã';
    } else {
      return DateFormat('dd/MM/yyyy').format(dueDate!);
    }
  }

  Color get dueDateColor {
    if (dueDate == null) return Colors.grey;
    
    final now = DateTime.now();
    final difference = dueDate!.difference(now);
    
    if (difference.isNegative) {
      return Colors.red;
    } else if (difference.inDays <= 1) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  bool isOverdue() {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  bool isToday() {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  int compareTo(Todo other, SortType sortType) {
    switch (sortType) {
      case SortType.priority:
        return priority.index.compareTo(other.priority.index);
      case SortType.dueDate:
        if (dueDate == null && other.dueDate == null) return 0;
        if (dueDate == null) return 1;
        if (other.dueDate == null) return -1;
        return dueDate!.compareTo(other.dueDate!);
      case SortType.category:
        return category.name.compareTo(other.category.name);
      case SortType.status:
        if (isDone == other.isDone) return 0;
        return isDone ? 1 : -1;
    }
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final int pointsRequired;
  final IconData icon;
  bool isUnlocked;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsRequired,
    required this.icon,
    this.isUnlocked = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'isUnlocked': isUnlocked,
  };

  factory Achievement.fromJson(Map<String, dynamic> json) {
    final achievement = achievements.firstWhere((a) => a.id == json['id']);
    achievement.isUnlocked = json['isUnlocked'];
    return achievement;
  }

  static final List<Achievement> achievements = [
    Achievement(
      id: 'first_task',
      title: 'Primeira Tarefa',
      description: 'Complete sua primeira tarefa',
      pointsRequired: 10,
      icon: Icons.star,
    ),
    Achievement(
      id: 'task_master',
      title: 'Mestre das Tarefas',
      description: 'Complete 10 tarefas',
      pointsRequired: 100,
      icon: Icons.workspace_premium,
    ),
    Achievement(
      id: 'category_expert',
      title: 'Especialista em Categorias',
      description: 'Use todas as categorias',
      pointsRequired: 50,
      icon: Icons.category,
    ),
    Achievement(
      id: 'subtask_pro',
      title: 'Profissional em Subtarefas',
      description: 'Complete 20 subtarefas',
      pointsRequired: 200,
      icon: Icons.checklist,
    ),
    Achievement(
      id: 'time_keeper',
      title: 'Guardião do Tempo',
      description: 'Complete 5 tarefas antes do prazo',
      pointsRequired: 150,
      icon: Icons.timer,
    ),
  ];
}

class UserProgress {
  int points;
  int level;
  List<Achievement> achievements;
  int tasksCompleted;
  int subtasksCompleted;
  int tasksCompletedOnTime;
  Set<String> categoriesUsed;
  Function(Achievement)? onAchievementUnlocked;

  UserProgress({
    this.points = 0,
    this.level = 1,
    List<Achievement>? achievements,
    this.tasksCompleted = 0,
    this.subtasksCompleted = 0,
    this.tasksCompletedOnTime = 0,
    Set<String>? categoriesUsed,
    this.onAchievementUnlocked,
  }) : achievements = achievements ?? Achievement.achievements,
       categoriesUsed = categoriesUsed ?? {};

  int get nextLevelPoints => level * 100;
  double get levelProgress => points / nextLevelPoints;

  void addPoints(int amount) {
    points += amount;
    while (points >= nextLevelPoints) {
      level++;
    }
  }

  void checkAchievements() {
    for (var achievement in achievements) {
      if (!achievement.isUnlocked) {
        switch (achievement.id) {
          case 'first_task':
            if (tasksCompleted >= 1) {
              achievement.isUnlocked = true;
              addPoints(achievement.pointsRequired);
              onAchievementUnlocked?.call(achievement);
            }
            break;
          case 'task_master':
            if (tasksCompleted >= 10) {
              achievement.isUnlocked = true;
              addPoints(achievement.pointsRequired);
              onAchievementUnlocked?.call(achievement);
            }
            break;
          case 'category_expert':
            if (categoriesUsed.length >= 5) {
              achievement.isUnlocked = true;
              addPoints(achievement.pointsRequired);
              onAchievementUnlocked?.call(achievement);
            }
            break;
          case 'subtask_pro':
            if (subtasksCompleted >= 20) {
              achievement.isUnlocked = true;
              addPoints(achievement.pointsRequired);
              onAchievementUnlocked?.call(achievement);
            }
            break;
          case 'time_keeper':
            if (tasksCompletedOnTime >= 5) {
              achievement.isUnlocked = true;
              addPoints(achievement.pointsRequired);
              onAchievementUnlocked?.call(achievement);
            }
            break;
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'points': points,
    'level': level,
    'achievements': achievements.map((a) => a.toJson()).toList(),
    'tasksCompleted': tasksCompleted,
    'subtasksCompleted': subtasksCompleted,
    'tasksCompletedOnTime': tasksCompletedOnTime,
    'categoriesUsed': categoriesUsed.toList(),
  };

  factory UserProgress.fromJson(Map<String, dynamic> json) => UserProgress(
    points: json['points'],
    level: json['level'],
    achievements: (json['achievements'] as List)
        .map((a) => Achievement.fromJson(a))
        .toList(),
    tasksCompleted: json['tasksCompleted'],
    subtasksCompleted: json['subtasksCompleted'],
    tasksCompletedOnTime: json['tasksCompletedOnTime'],
    categoriesUsed: Set<String>.from(json['categoriesUsed']),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lista de Tarefas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TodoListPage(),
    );
  }
}

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  final List<Todo> _todos = [];
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _subtaskController = TextEditingController();
  late ConfettiController _confettiController;
  static const String _todosKey = 'todos_key';
  static const List<Category> categories = [
    Category(name: 'Pessoal', color: Colors.blue),
    Category(name: 'Trabalho', color: Colors.red),
    Category(name: 'Compras', color: Colors.green),
    Category(name: 'Estudos', color: Colors.purple),
    Category(name: 'Outros', color: Colors.orange),
  ];
  Category _selectedCategory = categories[0];
  DateTime? _selectedDate;
  FilterType _currentFilter = FilterType.all;
  Category? _filterCategory;
  SortType _currentSort = SortType.priority;
  Priority _selectedPriority = Priority.medium;
  late UserProgress _userProgress;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    _userProgress = UserProgress(
      onAchievementUnlocked: _showAchievementDialog,
    );
    _loadTodos();
    _loadUserProgress();
  }

  List<Todo> get _filteredAndSortedTodos {
    final filtered = _todos.where((todo) {
      if (_filterCategory != null && todo.category.name != _filterCategory!.name) {
        return false;
      }

      switch (_currentFilter) {
        case FilterType.all:
          return true;
        case FilterType.pending:
          return !todo.isDone;
        case FilterType.completed:
          return todo.isDone;
        case FilterType.today:
          return todo.isToday();
        case FilterType.overdue:
          return todo.isOverdue();
      }
    }).toList();

    filtered.sort((a, b) => a.compareTo(b, _currentSort));
    return filtered;
  }

  void _toggleTodo(int index) {
    setState(() {
      final todo = _todos[index];
      todo.isDone = !todo.isDone;
      if (todo.isDone) {
        _userProgress.tasksCompleted++;
        if (todo.dueDate != null && todo.dueDate!.isAfter(DateTime.now())) {
          _userProgress.tasksCompletedOnTime++;
        }
      } else {
        _userProgress.tasksCompleted--;
        if (todo.dueDate != null && todo.dueDate!.isAfter(DateTime.now())) {
          _userProgress.tasksCompletedOnTime--;
        }
      }
      _userProgress.checkAchievements();
      _saveTodos();
      _saveUserProgress();
    });
  }

  void _toggleSubtask(Todo todo, int subtaskIndex) {
    setState(() {
      final subtask = todo.subtasks[subtaskIndex];
      subtask.isDone = !subtask.isDone;
      if (subtask.isDone) {
        _userProgress.subtasksCompleted++;
      } else {
        _userProgress.subtasksCompleted--;
      }
      _userProgress.checkAchievements();
      _saveTodos();
      _saveUserProgress();
    });
  }

  void _addTodo(String text) {
    if (text.isEmpty) return;

    setState(() {
      _todos.add(Todo(
        text: text,
        category: _selectedCategory,
        dueDate: _selectedDate,
        priority: _selectedPriority,
      ));
      _controller.clear();
      _selectedDate = null;
      _userProgress.categoriesUsed.add(_selectedCategory.name);
      _userProgress.checkAchievements();
      _saveTodos();
      _saveUserProgress();
    });
  }

  void _removeTodo(int index) {
    setState(() {
      final todo = _todos[index];
      if (todo.isDone) {
        _userProgress.tasksCompleted--;
        if (todo.dueDate != null && todo.dueDate!.isAfter(DateTime.now())) {
          _userProgress.tasksCompletedOnTime--;
        }
      }
      _userProgress.subtasksCompleted -= todo.subtasks.where((s) => s.isDone).length;
      _todos.removeAt(index);
      _saveTodos();
      _saveUserProgress();
    });
  }

  void _removeSubtask(Todo todo, int subtaskIndex) {
    setState(() {
      final subtask = todo.subtasks[subtaskIndex];
      if (subtask.isDone) {
        _userProgress.subtasksCompleted--;
      }
      todo.subtasks.removeAt(subtaskIndex);
      _saveTodos();
      _saveUserProgress();
    });
  }

  void _showAddSubtaskDialog(Todo todo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _subtaskController,
                decoration: const InputDecoration(
                  hintText: 'Digite uma nova subtarefa',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      todo.subtasks.add(Subtask(text: value));
                      _subtaskController.clear();
                      _saveTodos();
                    });
                    Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_subtaskController.text.isNotEmpty) {
                        setState(() {
                          todo.subtasks.add(Subtask(text: _subtaskController.text));
                          _subtaskController.clear();
                          _saveTodos();
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Adicionar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTaskDialog(Todo todo) {
    final TextEditingController textController = TextEditingController(text: todo.text);
    Category selectedCategory = todo.category;
    DateTime? selectedDate = todo.dueDate;
    Priority selectedPriority = todo.priority;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  hintText: 'Editar tarefa',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(category.name),
                              selected: selectedCategory.name == category.name,
                              selectedColor: category.color.withOpacity(0.3),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    selectedCategory = category;
                                    _userProgress.categoriesUsed.add(category.name);
                                    _userProgress.checkAchievements();
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: Priority.values.map((priority) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              avatar: Icon(
                                priority.icon,
                                size: 18,
                                color: selectedPriority == priority
                                    ? priority.color
                                    : Colors.grey,
                              ),
                              label: Text(priority.name),
                              selected: selectedPriority == priority,
                              selectedColor: priority.color.withOpacity(0.3),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    selectedPriority = priority;
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          selectedDate = date;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                          : 'Data',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (textController.text.isNotEmpty) {
                        setState(() {
                          todo.text = textController.text;
                          todo.category = selectedCategory;
                          todo.dueDate = selectedDate;
                          todo.priority = selectedPriority;
                          _saveTodos();
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAchievementsPage() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Conquistas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _userProgress.achievements.length,
                itemBuilder: (context, index) {
                  final achievement = _userProgress.achievements[index];
                  return ListTile(
                    leading: Icon(
                      achievement.isUnlocked ? Icons.emoji_events : Icons.lock,
                      color: achievement.isUnlocked ? Colors.amber : Colors.grey,
                    ),
                    title: Text(achievement.title),
                    subtitle: Text(achievement.description),
                    trailing: achievement.isUnlocked
                        ? Text(
                            '+${achievement.pointsRequired}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAchievementDialog(Achievement achievement) {
    _confettiController.play();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber),
            const SizedBox(width: 8),
            const Text('Nova Conquista!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              achievement.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(achievement.description),
            const SizedBox(height: 16),
            Text(
              '+${achievement.pointsRequired} pontos',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? todosJson = prefs.getString(_todosKey);
    if (todosJson != null) {
      setState(() {
        _todos.clear();
        final List<dynamic> decoded = jsonDecode(todosJson);
        _todos.addAll(decoded.map((item) => Todo.fromJson(item)));
      });
    }
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_todos);
    await prefs.setString(_todosKey, encoded);
  }

  Future<void> _loadUserProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final String? progressJson = prefs.getString('user_progress');
    if (progressJson != null) {
      setState(() {
        _userProgress = UserProgress.fromJson(
          jsonDecode(progressJson),
        )..onAchievementUnlocked = _showAchievementDialog;
      });
    }
  }

  Future<void> _saveUserProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_progress', jsonEncode(_userProgress));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Minhas Tarefas'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.trending_up, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Nível ${_userProgress.level}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<SortType>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar por',
            onSelected: (SortType sortType) {
              setState(() {
                _currentSort = sortType;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortType>>[
              const PopupMenuItem<SortType>(
                value: SortType.priority,
                child: Text('Prioridade'),
              ),
              const PopupMenuItem<SortType>(
                value: SortType.dueDate,
                child: Text('Data'),
              ),
              const PopupMenuItem<SortType>(
                value: SortType.category,
                child: Text('Categoria'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events),
            onPressed: _showAchievementsPage,
            tooltip: 'Conquistas',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${_userProgress.points} pontos',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        Text(
                          'Próximo nível: ${_userProgress.nextLevelPoints - _userProgress.points} pontos',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _userProgress.levelProgress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).primaryColor,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredAndSortedTodos.length,
                  itemBuilder: (context, index) {
                    final todo = _filteredAndSortedTodos[index];
                    return ExpansionTile(
                      initiallyExpanded: false,
                      maintainState: true,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            todo.priority.icon,
                            color: todo.priority.color,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: todo.isDone,
                            onChanged: (_) => _toggleTodo(index),
                          ),
                        ],
                      ),
                      title: Text(
                        todo.text,
                        style: TextStyle(
                          decoration: todo.isDone ? TextDecoration.lineThrough : null,
                          color: todo.isDone ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: todo.category.color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  todo.category.name,
                                  style: TextStyle(
                                    color: todo.category.color,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: todo.dueDateColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  todo.dueDateText,
                                  style: TextStyle(
                                    color: todo.dueDateColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (todo.subtasks.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: todo.progress,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(
                                todo.priority.color,
                              ),
                              minHeight: 4,
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditTaskDialog(todo),
                            tooltip: 'Editar tarefa',
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_task),
                            onPressed: () => _showAddSubtaskDialog(todo),
                            tooltip: 'Adicionar subtarefa',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeTodo(index),
                            tooltip: 'Remover tarefa',
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (todo.subtasks.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Nenhuma subtarefa',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: todo.subtasks.length,
                                  itemBuilder: (context, subtaskIndex) {
                                    final subtask = todo.subtasks[subtaskIndex];
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Checkbox(
                                        value: subtask.isDone,
                                        onChanged: (_) =>
                                            _toggleSubtask(todo, subtaskIndex),
                                      ),
                                      title: Text(
                                        subtask.text,
                                        style: TextStyle(
                                          decoration: subtask.isDone
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: subtask.isDone ? Colors.grey : null,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () =>
                                            _removeSubtask(todo, subtaskIndex),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: -pi / 2,
            emissionFrequency: 0.3,
            numberOfParticles: 20,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, size: 20),
                const SizedBox(width: 4),
                Text(
                  'Tarefas: ${_userProgress.tasksCompleted}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.category, size: 20),
                const SizedBox(width: 4),
                Text(
                  'Categorias: ${_userProgress.categoriesUsed.length}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.emoji_events),
              onPressed: _showAchievementsPage,
              tooltip: 'Ver conquistas',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Digite uma nova tarefa',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) {
                        _addTodo(value);
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: categories.map((category) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: ChoiceChip(
                                    label: Text(category.name),
                                    selected: _selectedCategory.name == category.name,
                                    selectedColor: category.color.withOpacity(0.3),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedCategory = category;
                                          _userProgress.categoriesUsed.add(category.name);
                                          _userProgress.checkAchievements();
                                        });
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: Priority.values.map((priority) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: ChoiceChip(
                                    avatar: Icon(
                                      priority.icon,
                                      size: 18,
                                      color: _selectedPriority == priority
                                          ? priority.color
                                          : Colors.grey,
                                    ),
                                    label: Text(priority.name),
                                    selected: _selectedPriority == priority,
                                    selectedColor: priority.color.withOpacity(0.3),
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedPriority = priority;
                                        });
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _selectDate(context),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _selectedDate != null
                                ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                                : 'Data',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _subtaskController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
}
