import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/organization_repository.dart';
import '../models/appointment_model.dart';

class OrganizationScreen extends StatelessWidget {
  const OrganizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Organização'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.shopping_cart), text: 'Compras'),
              Tab(icon: Icon(Icons.check_box), text: 'Afazeres'),
              Tab(icon: Icon(Icons.calendar_month), text: 'Agenda'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ShoppingTab(),
            _TodosTab(),
            _AppointmentsTab(),
          ],
        ),
      ),
    );
  }
}

// --- TAB DE COMPRAS ---
class _ShoppingTab extends ConsumerStatefulWidget {
  const _ShoppingTab();
  @override
  ConsumerState<_ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends ConsumerState<_ShoppingTab> {
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

// --- TAB DE AFAZERES ---
class _TodosTab extends ConsumerStatefulWidget {
  const _TodosTab();
  @override
  ConsumerState<_TodosTab> createState() => _TodosTabState();
}

class _TodosTabState extends ConsumerState<_TodosTab> {
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
                  value: _assignedTo,
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

// --- TAB DE AGENDA ---
class _AppointmentsTab extends ConsumerStatefulWidget {
  const _AppointmentsTab();
  @override
  ConsumerState<_AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends ConsumerState<_AppointmentsTab> {
  void _showAppointmentDialog(BuildContext context, OrganizationRepository repo, {AppointmentModel? appointment}) {
    final titleController = TextEditingController(text: appointment?.title);
    final costController = TextEditingController(
      text: appointment?.expectedCost != null ? appointment!.expectedCost!.toStringAsFixed(2) : ''
    );
    DateTime selectedDate = appointment?.date ?? DateTime.now();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      appointment == null ? 'Novo Compromisso' : 'Editar Compromisso',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Título do compromisso'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Data: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000), // Allowing past for editing
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          setState(() => selectedDate = date);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: costController,
                      decoration: const InputDecoration(
                        labelText: 'Custo Previsto (R\$)',
                        hintText: 'Opcional',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;
                        
                        final costText = costController.text.replaceAll(',', '.');
                        final cost = double.tryParse(costText);

                        setState(() => isLoading = true);
                        try {
                          if (appointment == null) {
                            await repo.addAppointment(title, selectedDate, expectedCost: cost);
                          } else {
                            final updated = appointment.copyWith(
                              title: title,
                              date: selectedDate,
                              expectedCost: cost,
                            );
                            await repo.updateAppointment(updated);
                          }
                          if (mounted) Navigator.pop(ctx);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                          setState(() => isLoading = false);
                        }
                      },
                      child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Salvar'),
                    ),
                    if (appointment != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isLoading ? null : () async {
                          setState(() => isLoading = true);
                          try {
                            await repo.deleteAppointment(appointment.id);
                            if (mounted) Navigator.pop(ctx);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao apagar: $e')));
                            setState(() => isLoading = false);
                          }
                        },
                        child: const Text('Excluir Compromisso', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apptsAsync = ref.watch(appointmentsProvider);
    final repo = ref.watch(organizationRepositoryProvider);

    return Column(
      children: [
        Expanded(
          child: apptsAsync.when(
            data: (items) {
              if (items.isEmpty) return const Center(child: Text('Nenhum compromisso agendado'));
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Dismissible(
                    key: ValueKey(item.id),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => repo.deleteAppointment(item.id),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.event, color: Colors.white),
                      ),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.date.day.toString().padLeft(2, '0')}/${item.date.month.toString().padLeft(2, '0')}/${item.date.year} às 08:00'),
                          if (item.expectedCost != null)
                            Text('Custo Previsto: R\$ ${item.expectedCost!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange)),
                        ],
                      ),
                      trailing: const Icon(Icons.notifications_active, color: Colors.green, size: 16),
                      onTap: () => _showAppointmentDialog(context, repo, appointment: item),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Compromisso'),
              onPressed: () => _showAppointmentDialog(context, repo),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
