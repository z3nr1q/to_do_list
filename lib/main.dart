import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

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
  dateAsc,
  dateDesc,
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

class Todo {
  String text;
  bool isDone;
  Category category;
  DateTime? dueDate;
  Priority priority;

  Todo({
    required this.text,
    this.isDone = false,
    required this.category,
    this.dueDate,
    this.priority = Priority.medium,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isDone': isDone,
    'category': category.toJson(),
    'dueDate': dueDate?.toIso8601String(),
    'priority': priority.index,
  };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    text: json['text'],
    isDone: json['isDone'],
    category: Category.fromJson(json['category']),
    dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
    priority: Priority.values[json['priority'] ?? Priority.medium.index],
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
      case SortType.dateAsc:
        if (dueDate == null && other.dueDate == null) return 0;
        if (dueDate == null) return 1;
        if (other.dueDate == null) return -1;
        return dueDate!.compareTo(other.dueDate!);
      case SortType.dateDesc:
        if (dueDate == null && other.dueDate == null) return 0;
        if (dueDate == null) return 1;
        if (other.dueDate == null) return -1;
        return other.dueDate!.compareTo(dueDate!);
      case SortType.category:
        return category.name.compareTo(other.category.name);
      case SortType.status:
        if (isDone == other.isDone) return 0;
        return isDone ? 1 : -1;
    }
  }
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
  static const String _todosKey = 'todos_key';
  Category _selectedCategory = categories[0];
  DateTime? _selectedDate;
  FilterType _currentFilter = FilterType.all;
  Category? _filterCategory;
  SortType _currentSort = SortType.priority;
  Priority _selectedPriority = Priority.medium;

  static const List<Category> categories = [
    Category(name: 'Pessoal', color: Colors.blue),
    Category(name: 'Trabalho', color: Colors.red),
    Category(name: 'Compras', color: Colors.green),
    Category(name: 'Estudos', color: Colors.purple),
    Category(name: 'Outros', color: Colors.orange),
  ];

  @override
  void initState() {
    super.initState();
    _loadTodos();
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

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = prefs.getStringList(_todosKey);
    if (todosJson != null) {
      setState(() {
        _todos.clear();
        _todos.addAll(
          todosJson.map((todo) => Todo.fromJson(jsonDecode(todo))),
        );
      });
    }
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = _todos.map((todo) => jsonEncode(todo.toJson())).toList();
    await prefs.setStringList(_todosKey, todosJson);
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

  void _addTodo(String text) {
    if (text.isNotEmpty) {
      setState(() {
        _todos.add(Todo(
          text: text,
          category: _selectedCategory,
          dueDate: _selectedDate,
          priority: _selectedPriority,
        ));
        _selectedDate = null;
      });
      _saveTodos();
      _controller.clear();
    }
  }

  void _toggleTodo(int index) {
    final todoIndex = _todos.indexOf(_filteredAndSortedTodos[index]);
    setState(() {
      _todos[todoIndex].isDone = !_todos[todoIndex].isDone;
    });
    _saveTodos();
  }

  void _removeTodo(int index) {
    final todoIndex = _todos.indexOf(_filteredAndSortedTodos[index]);
    setState(() {
      _todos.removeAt(todoIndex);
    });
    _saveTodos();
  }

  String _getSortText() {
    switch (_currentSort) {
      case SortType.priority:
        return 'Prioridade';
      case SortType.dateAsc:
        return 'Data ↑';
      case SortType.dateDesc:
        return 'Data ↓';
      case SortType.category:
        return 'Categoria';
      case SortType.status:
        return 'Status';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<SortType>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar por',
            onSelected: (SortType sort) {
              setState(() {
                _currentSort = sort;
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: SortType.priority,
                child: Text('Prioridade'),
              ),
              const PopupMenuItem(
                value: SortType.dateAsc,
                child: Text('Data (mais próxima)'),
              ),
              const PopupMenuItem(
                value: SortType.dateDesc,
                child: Text('Data (mais distante)'),
              ),
              const PopupMenuItem(
                value: SortType.category,
                child: Text('Categoria'),
              ),
              const PopupMenuItem(
                value: SortType.status,
                child: Text('Status'),
              ),
            ],
          ),
          PopupMenuButton<FilterType>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar por',
            onSelected: (FilterType filter) {
              setState(() {
                _currentFilter = filter;
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: FilterType.all,
                child: Text('Todas'),
              ),
              const PopupMenuItem(
                value: FilterType.pending,
                child: Text('Pendentes'),
              ),
              const PopupMenuItem(
                value: FilterType.completed,
                child: Text('Concluídas'),
              ),
              const PopupMenuItem(
                value: FilterType.today,
                child: Text('Para hoje'),
              ),
              const PopupMenuItem(
                value: FilterType.overdue,
                child: Text('Atrasadas'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Digite uma nova tarefa',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: _addTodo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _addTodo(_controller.text),
                      child: const Text('Adicionar'),
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
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: const Text('Todas'),
                                selected: _filterCategory == null,
                                onSelected: (selected) {
                                  setState(() {
                                    _filterCategory = null;
                                  });
                                },
                              ),
                            ),
                            ...categories.map((category) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: FilterChip(
                                  label: Text(category.name),
                                  selected: _filterCategory?.name == category.name,
                                  selectedColor: category.color.withOpacity(0.3),
                                  onSelected: (selected) {
                                    setState(() {
                                      _filterCategory = selected ? category : null;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ],
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.sort, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Ordenado por: ${_getSortText()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredAndSortedTodos.length,
              itemBuilder: (context, index) {
                final todo = _filteredAndSortedTodos[index];
                return ListTile(
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
                  subtitle: Row(
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
                      const SizedBox(width: 8),
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
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeTodo(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
