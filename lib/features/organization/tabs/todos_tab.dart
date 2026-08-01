import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/organization_repository.dart';

class TodosTab extends ConsumerStatefulWidget {
  const TodosTab({super.key});
  @override
  ConsumerState<TodosTab> createState() => _TodosTabState();
}

class _TodosTabState extends ConsumerState<TodosTab> {
  final _controller = TextEditingController();
  String _assignedTo = 'both';

  @override
  Widget build(BuildContext context) {
    final todosAsync = ref.watch(todosProvider);
    final repo = ref.watch(organizationRepositoryProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(labelText: 'Nova tarefa'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _assignedTo,
                  items: const [
                    DropdownMenuItem(value: 'both', child: Text('Ambos')),
                    DropdownMenuItem(value: 'me', child: Text('Eu')),
                    DropdownMenuItem(value: 'partner', child: Text('Ela/Ele')),
                  ],
                  onChanged: (val) => setState(() => _assignedTo = val!),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Theme.of(context).primaryColor,
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    repo.addTodo(_controller.text, _assignedTo);
                    _controller.clear();
                    setState(() => _assignedTo = 'both');
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: todosAsync.when(
            data: (items) {
              if (items.isEmpty) return const Center(child: Text('Nenhuma tarefa'));
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  Icon assignedIcon;
                  if (item.assignedTo == 'me') {
                    assignedIcon = const Icon(Icons.person, color: Colors.blue);
                  } else if (item.assignedTo == 'partner') {
                    assignedIcon = const Icon(Icons.favorite, color: Colors.pink);
                  } else {
                    assignedIcon = const Icon(Icons.group, color: Colors.purple);
                  }

                  return Dismissible(
                    key: ValueKey(item.id),
                    background: Container(color: Colors.red),
                    onDismissed: (_) => repo.deleteTodo(item.id),
                    child: CheckboxListTile(
                      secondary: assignedIcon,
                      title: Text(
                        item.title,
                        style: TextStyle(
                          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                          color: item.isCompleted ? Colors.grey : null,
                        ),
                      ),
                      value: item.isCompleted,
                      onChanged: (_) => repo.toggleTodo(item),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
          ),
        ),
      ],
    );
  }
}
