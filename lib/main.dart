import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
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

  Todo({
    required this.text,
    this.isDone = false,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isDone': isDone,
    'category': category.toJson(),
  };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    text: json['text'],
    isDone: json['isDone'],
    category: Category.fromJson(json['category']),
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
  static const String _todosKey = 'todos_key';
  Category _selectedCategory = categories[0];

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

  void _addTodo(String text) {
    if (text.isNotEmpty) {
      setState(() {
        _todos.add(Todo(
          text: text,
          category: _selectedCategory,
        ));
      });
      _saveTodos();
      _controller.clear();
    }
  }

  void _toggleTodo(int index) {
    setState(() {
      _todos[index].isDone = !_todos[index].isDone;
    });
    _saveTodos();
  }

  void _removeTodo(int index) {
    setState(() {
      _todos.removeAt(index);
    });
    _saveTodos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                SingleChildScrollView(
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
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _todos.length,
              itemBuilder: (context, index) {
                final todo = _todos[index];
                return ListTile(
                  leading: Checkbox(
                    value: todo.isDone,
                    onChanged: (_) => _toggleTodo(index),
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
