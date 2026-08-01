import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/organization_repository.dart';

class ShoppingTab extends ConsumerStatefulWidget {
  const ShoppingTab({super.key});
  @override
  ConsumerState<ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends ConsumerState<ShoppingTab> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final shoppingAsync = ref.watch(shoppingListProvider);
    final repo = ref.watch(organizationRepositoryProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(labelText: 'Novo item'),
                  onSubmitted: (val) {
                    if (val.isNotEmpty) {
                      repo.addShoppingItem(val);
                      _controller.clear();
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Theme.of(context).primaryColor,
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    repo.addShoppingItem(_controller.text);
                    _controller.clear();
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: shoppingAsync.when(
            data: (items) {
              if (items.isEmpty) return const Center(child: Text('Lista vazia'));
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Dismissible(
                    key: ValueKey(item.id),
                    background: Container(color: Colors.red),
                    onDismissed: (_) => repo.deleteShoppingItem(item.id),
                    child: CheckboxListTile(
                      title: Text(
                        item.name,
                        style: TextStyle(
                          decoration: item.isBought ? TextDecoration.lineThrough : null,
                          color: item.isBought ? Colors.grey : null,
                        ),
                      ),
                      value: item.isBought,
                      onChanged: (_) => repo.toggleShoppingItem(item),
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
