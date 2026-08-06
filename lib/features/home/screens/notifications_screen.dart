import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../finances/repositories/finances_repository.dart';
import '../../organization/repositories/organization_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          return appointmentsAsync.when(
            data: (appointments) {
              final now = DateTime.now();
              final notifications = <_NotificationItem>[];

              // Cartões
              for (var c in categories) {
                if (c.closingDay != null) {
                  final closingDate = DateTime(now.year, now.month, c.closingDay!);
                  final diff = closingDate.difference(now).inDays;
                  if (diff >= -1 && diff <= 3) {
                    notifications.add(_NotificationItem(
                      title: 'Cartão Fechando',
                      message: 'A fatura do cartão ${c.name} fecha ${diff == 0 ? 'hoje' : diff == 1 ? 'amanhã' : diff < 0 ? 'ontem' : 'em $diff dias'}.',
                      icon: Icons.credit_card,
                      color: Colors.orange,
                      date: closingDate,
                    ));
                  }
                }
                if (c.dueDay != null) {
                  final dueDate = DateTime(now.year, now.month, c.dueDay!);
                  final diff = dueDate.difference(now).inDays;
                  if (diff >= -1 && diff <= 3) {
                    notifications.add(_NotificationItem(
                      title: 'Fatura Vencendo',
                      message: 'A fatura do cartão ${c.name} vence ${diff == 0 ? 'hoje' : diff == 1 ? 'amanhã' : diff < 0 ? 'ontem' : 'em $diff dias'}.',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                      date: dueDate,
                    ));
                  }
                }
              }

              // Compromissos
              for (var a in appointments) {
                final date = a.date;
                final diff = DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
                if (diff >= 0 && diff <= 2) {
                  notifications.add(_NotificationItem(
                    title: 'Compromisso Próximo',
                    message: '${a.title} é ${diff == 0 ? 'hoje' : diff == 1 ? 'amanhã' : 'em $diff dias'}.',
                    icon: Icons.event,
                    color: Colors.blue,
                    date: date,
                  ));
                }
              }

              notifications.sort((a, b) => a.date.compareTo(b.date));

              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Você não tem novas notificações',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: notif.color.withValues(alpha: 0.1),
                      child: Icon(notif.icon, color: notif.color),
                    ),
                    title: Text(notif.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(notif.message),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Erro: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

class _NotificationItem {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final DateTime date;

  _NotificationItem({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.date,
  });
}
