import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/finances_repository.dart';
import '../models/loan_model.dart';
import 'add_loan_screen.dart';
import '../widgets/month_selector.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Empréstimos'),
      ),
      body: loansAsync.when(
        data: (loans) {
          return categoriesAsync.when(
            data: (categories) {
              // Pega pendentes até o mês selecionado
              final pendingThisMonth = loans.where((l) => 
                !l.isPaid && 
                (l.date.year < selectedMonth.year || (l.date.year == selectedMonth.year && l.date.month <= selectedMonth.month))
              ).toList();

          final groupedByPerson = <String, double>{};
          for (var loan in pendingThisMonth) {
            groupedByPerson[loan.borrowerName] = (groupedByPerson[loan.borrowerName] ?? 0) + loan.amount;
          }

          final totalPending = groupedByPerson.values.fold<double>(0, (sum, val) => sum + val);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MonthSelector(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: Colors.orangeAccent.shade100,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text(
                            'A Receber (Até este Mês)',
                            style: TextStyle(color: Colors.black54, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'R\$ ${totalPending.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (groupedByPerson.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.black12),
                            const SizedBox(height: 8),
                            ...groupedByPerson.entries.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('R\$ ${e.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Parcelas do Mês',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final currentMonthLoans = loans.where((l) => l.date.year == selectedMonth.year && l.date.month == selectedMonth.month).toList();
                    if (currentMonthLoans.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('Nenhum empréstimo para este mês.')),
                      );
                    }

                    final allGrouped = <String, List<LoanModel>>{};
                    for (var loan in currentMonthLoans) {
                      allGrouped.putIfAbsent(loan.borrowerName, () => []).add(loan);
                    }
                    final personNames = allGrouped.keys.toList();

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: personNames.length,
                      itemBuilder: (context, index) {
                        final person = personNames[index];
                        final personLoans = allGrouped[person]!;
                        final totalPersonDebt = personLoans
                            .fold<double>(0, (sum, l) => sum + l.amount);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 1,
                          child: ExpansionTile(
                            title: Text(person, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'Parcelas no mês: R\$ ${totalPersonDebt.toStringAsFixed(2)}',
                              style: TextStyle(color: totalPersonDebt > 0 ? Colors.deepOrange : Colors.green),
                            ),
                            children: () {
                              final widgets = <Widget>[];

                              // Mostra resumo por cartão para este mês
                              final debtByCard = <String, double>{};
                              for (var l in personLoans) {
                                debtByCard[l.categoryId] = (debtByCard[l.categoryId] ?? 0) + l.amount;
                              }
                                                               if (debtByCard.isNotEmpty) {
                                      widgets.add(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          width: double.infinity,
                                          color: Colors.orange.shade50,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: debtByCard.entries.map((e) {
                                              final card = categories.where((c) => c.id == e.key).firstOrNull;
                                              final cardName = card?.name ?? 'Outros/Deletado';
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                                child: Text(
                                                  '• Cartão $cardName: R\$ ${e.value.toStringAsFixed(2)}',
                                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepOrange),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        )
                                      );
                                    }

                                    // Ordena os empréstimos do mês por data (crescente)
                                    personLoans.sort((a, b) => a.date.compareTo(b.date));

                                    widgets.addAll(personLoans.map((loan) {
                                      final card = categories.where((c) => c.id == loan.categoryId).firstOrNull;
                                      final cardName = card?.name ?? '';
                                      return Dismissible(
                                        key: ValueKey(loan.id),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          color: Colors.red,
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 20),
                                          child: const Icon(Icons.delete, color: Colors.white),
                                        ),
                                        onDismissed: (_) {
                                          ref.read(financesRepositoryProvider).deleteLoan(loan.id);
                                        },
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: loan.isPaid ? Colors.green.shade100 : Colors.orange.shade100,
                                            child: Icon(
                                              loan.isPaid ? Icons.check : Icons.access_time,
                                              color: loan.isPaid ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                          title: Text('Valor: R\$ ${loan.amount.toStringAsFixed(2)}'),
                                          subtitle: Text(
                                            '${cardName.isNotEmpty ? 'Cartão: $cardName\n' : ''}Data: ${loan.date.day.toString().padLeft(2, '0')}/${loan.date.month.toString().padLeft(2, '0')}/${loan.date.year}${loan.totalInstallments > 1 ? '\nParcela ${loan.currentInstallment}/${loan.totalInstallments}' : ''}'
                                          ),
                                          trailing: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                loan.isPaid ? 'Pago' : 'Pendente',
                                                style: TextStyle(
                                                  color: loan.isPaid ? Colors.green : Colors.orange,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AddLoanScreen(loan: loan),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }));
                                    return widgets;
                                  }(),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro nas categorias: $e')),
      );
    },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}
