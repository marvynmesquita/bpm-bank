import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/organization_repository.dart';
import '../widgets/appointment_dialog.dart';

class AppointmentsTab extends ConsumerStatefulWidget {
  const AppointmentsTab({super.key});
  @override
  ConsumerState<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends ConsumerState<AppointmentsTab> {
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
                      onTap: () => showAppointmentDialog(context, repo, appointment: item),
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
              onPressed: () => showAppointmentDialog(context, repo),
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
