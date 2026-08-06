import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/finances_repository.dart';
import '../models/expense_model.dart';
import '../widgets/month_selector.dart';
import 'add_expense_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Column(
        children: const [
          MonthSelector(),
          Expanded(
            child: _ExpensesListWidget(),
          ),
        ],
      ),
    );
  }
}

class _ExpensesListWidget extends ConsumerStatefulWidget {
  const _ExpensesListWidget();

  @override
  ConsumerState<_ExpensesListWidget> createState() => _ExpensesListWidgetState();
}

class _ExpensesListWidgetState extends ConsumerState<_ExpensesListWidget> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(currentMonthExpensesProvider);

    return expensesAsync.when(
      data: (expenses) {
        final totalGastos = expenses.where((e) => !e.isIncome).fold<double>(0, (sum, e) => sum + e.effectiveAmount);
        final totalRenda = expenses.where((e) => e.isIncome).fold<double>(0, (sum, e) => sum + e.effectiveAmount);
        
        final filteredExpenses = expenses.where((e) {
          final desc = (e.description ?? '').toLowerCase();
          final cat = (e.category?.name ?? '').toLowerCase();
          return desc.contains(_searchQuery) || cat.contains(_searchQuery);
        }).toList();
        
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 0,
                      color: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text('Gastos', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              'R\$ ${totalGastos.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      elevation: 0,
                      color: Colors.green.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text('Renda Extra', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              'R\$ ${totalRenda.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Despesas Recentes',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Pesquisar...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: filteredExpenses.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final expense = filteredExpenses[index];
                    return Dismissible(
                      key: ValueKey(expense.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        ref.read(financesRepositoryProvider).deleteExpense(expense.id);
                      },
                      child: ListTile(
                        title: Text(
                          expense.description ?? 'Sem descrição',
                          style: TextStyle(color: expense.isIncome ? Colors.green.shade700 : null),
                        ),
                        subtitle: Text(
                          '${expense.isIncome ? 'Renda' : (expense.category?.name ?? 'Sem categoria')}${expense.isRecurring ? ' (Recorrente)' : ''}'
                        ),
                        trailing: Text(
                          'R\$ ${expense.effectiveAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: expense.isIncome ? Colors.green : Colors.red,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddExpenseScreen(expense: expense),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Erro ao carregar despesas: $e')),
    );
  }
}
