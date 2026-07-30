import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/finances_repository.dart';
import '../models/loan_model.dart';
import 'add_loan_screen.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Empréstimos'),
      ),
      body: loansAsync.when(
        data: (loans) {
          return categoriesAsync.when(
            data: (categories) {
              final now = DateTime.now();
              // Pega pendentes até o mês atual
              final pendingThisMonth = loans.where((l) => 
                !l.isPaid && 
                (l.date.year < now.year || (l.date.year == now.year && l.date.month <= now.month))
              ).toList();

          final groupedByPerson = <String, double>{};
          for (var loan in pendingThisMonth) {
            groupedByPerson[loan.borrowerName] = (groupedByPerson[loan.borrowerName] ?? 0) + loan.amount;
          }

          final totalPending = groupedByPerson.values.fold<double>(0, (sum, val) => sum + val);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                          'A Receber (Este Mês)',
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
                  'Histórico de Empréstimos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: loans.isEmpty
                    ? const Center(child: Text('Nenhum empréstimo registrado.'))
                    : Builder(
                        builder: (context) {
                          final allGrouped = <String, List<LoanModel>>{};
                          for (var loan in loans) {
                            allGrouped.putIfAbsent(loan.borrowerName, () => []).add(loan);
                          }
                          final personNames = allGrouped.keys.toList();

                          return ListView.builder(
                            itemCount: personNames.length,
                            itemBuilder: (context, index) {
                              final person = personNames[index];
                              final personLoans = allGrouped[person]!;
                              final now = DateTime.now();
                              final totalPersonDebt = personLoans
                                  .where((l) => !l.isPaid && (l.date.year < now.year || (l.date.year == now.year && l.date.month <= now.month)))
                                  .fold<double>(0, (sum, l) => sum + l.amount);

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                elevation: 1,
                                child: ExpansionTile(
                                  title: Text(person, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    'Pendente (Este Mês): R\$ ${totalPersonDebt.toStringAsFixed(2)}',
                                    style: TextStyle(color: totalPersonDebt > 0 ? Colors.deepOrange : Colors.green),
                                  ),
                                  children: () {
                                    // Agrupa as parcelas da pessoa por mês/ano
                                    final loansByMonth = <String, List<LoanModel>>{};
                                    for (var loan in personLoans) {
                                      final monthKey = '${loan.date.month.toString().padLeft(2, '0')}/${loan.date.year}';
                                      loansByMonth.putIfAbsent(monthKey, () => []).add(loan);
                                    }
                                    
                                    // Ordena as chaves (meses) cronologicamente
                                    final sortedMonths = loansByMonth.keys.toList()..sort((a, b) {
                                      final partsA = a.split('/');
                                      final partsB = b.split('/');
                                      final dateA = DateTime(int.parse(partsA[1]), int.parse(partsA[0]));
                                      final dateB = DateTime(int.parse(partsB[1]), int.parse(partsB[0]));
                                      return dateA.compareTo(dateB);
                                    });

                                    final widgets = <Widget>[];

                                    // Mostra resumo por cartão
                                    final debtByCard = <String, double>{};
                                    for (var l in personLoans.where((l) => !l.isPaid && (l.date.year < now.year || (l.date.year == now.year && l.date.month <= now.month)))) {
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

                                    for (var monthKey in sortedMonths) {
                                      widgets.add(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          width: double.infinity,
                                          color: Colors.grey.shade100,
                                          child: Text(
                                            'Mês: $monthKey',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                                          ),
                                        )
                                      );
                                      
                                      final monthLoans = loansByMonth[monthKey]!;
                                      // Ordena os empréstimos do mês por data (crescente)
                                      monthLoans.sort((a, b) => a.date.compareTo(b.date));

                                      widgets.addAll(monthLoans.map((loan) {
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
                                              (cardName.isNotEmpty ? 'Cartão: $cardName\n' : '') +
                                              'Data: ${loan.date.day.toString().padLeft(2, '0')}/${loan.date.month.toString().padLeft(2, '0')}/${loan.date.year}'
                                              '${loan.totalInstallments > 1 ? '\nParcela ${loan.currentInstallment}/${loan.totalInstallments}' : ''}'
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
                                    }
                                    return widgets;
                                  }(),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
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
