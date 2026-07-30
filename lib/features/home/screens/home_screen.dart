import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../finances/repositories/finances_repository.dart';
import '../../finances/models/category_model.dart';
import '../../finances/models/expense_model.dart';
import '../../../core/services/groq_service.dart';

final geminiInsightProvider = FutureProvider<String>((ref) async {
  final expenses = await ref.watch(currentMonthExpensesProvider.future);
  if (expenses.isEmpty) {
    return 'Adicione suas primeiras despesas para receber um insight financeiro.';
  }

  // Agrupar por categoria
  final summary = <String, Map<String, dynamic>>{};
  for (var e in expenses) {
    final catName = e.category?.name ?? 'Outros';
    final type = e.category?.type ?? 'outros';
    
    if (!summary.containsKey(catName)) {
      summary[catName] = {'amount': 0.0, 'type': type};
    }
    summary[catName]!['amount'] = (summary[catName]!['amount'] as double) + e.effectiveAmount;
  }

  final summaryStr = summary.entries.map((e) => '${e.key} (${e.value['type']}): R\$ ${e.value['amount']}').join(', ');
  
  final groq = GroqService();
  return await groq.getFinancialInsight(summaryStr);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void showCategoryExpenses(CategoryModel cat, List<ExpenseModel> allExpenses) {
      final catExpenses = allExpenses.where((e) => e.categoryId == cat.id).toList();
      catExpenses.sort((a, b) => b.date.compareTo(a.date));

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Despesas: ${cat.name}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: catExpenses.isEmpty
                        ? const Center(child: Text('Nenhuma despesa registrada neste mês.'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: catExpenses.length,
                            itemBuilder: (context, index) {
                              final e = catExpenses[index];
                              return ListTile(
                                title: Text(e.description != null && e.description!.isNotEmpty ? e.description! : 'Sem descrição'),
                                subtitle: Text('${e.date.day.toString().padLeft(2, '0')}/${e.date.month.toString().padLeft(2, '0')}/${e.date.year}'),
                                trailing: Text(
                                  'R\$ ${e.effectiveAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    final expensesAsync = ref.watch(currentMonthExpensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final insightAsync = ref.watch(geminiInsightProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Visão Geral')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(24.0),
                child: insightAsync.when(
                  data: (insight) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.amberAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Insight da IA',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        insight,
                        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                      ),
                    ],
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  error: (e, _) => Text(
                    'Erro ao gerar insight: $e',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Resumo Rápido',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            expensesAsync.when(
              data: (expenses) {
                final total = expenses.fold<double>(0, (sum, e) => sum + e.effectiveAmount);
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEF4444),
                      child: Icon(Icons.arrow_downward, color: Colors.white),
                    ),
                    title: const Text('Gastos deste Mês'),
                    trailing: Text(
                      'R\$ ${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erro: $e'),
            ),
            categoriesAsync.when(
              data: (categories) {
                final fixedCategories = categories.where((c) => c.type == 'fixa').toList();
                final creditCards = categories.where((c) => c.type == 'credito').toList();
                final benefits = categories.where((c) => c.type == 'beneficio').toList();
                if (fixedCategories.isEmpty && creditCards.isEmpty && benefits.isEmpty) return const SizedBox.shrink();

                return expensesAsync.when(
                  data: (expenses) {
                    final summary = <String, double>{};
                    for (var e in expenses) {
                      final catId = e.categoryId;
                      if (catId != null) {
                        summary[catId] = (summary[catId] ?? 0) + e.effectiveAmount;
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'Acompanhamento de Limites',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ...fixedCategories.map((cat) {
                          final spent = summary[cat.id] ?? 0.0;
                          final fixed = cat.fixedValue;
                          final percentage = (fixed != null && fixed > 0) ? (spent / fixed).clamp(0.0, 1.0) : 0.0;
                          
                          Color barColor = Colors.green;
                          if (percentage >= 0.9) {
                            barColor = Colors.red;
                          } else if (percentage >= 0.7) {
                            barColor = Colors.orange;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => showCategoryExpenses(cat, expenses),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            if (cat.dueDay != null)
                                              Text('Vencimento: Dia ${cat.dueDay}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                                          ],
                                        ),
                                        Text(fixed != null ? '${(percentage * 100).toStringAsFixed(0)}%' : 'Sem limite', style: TextStyle(color: fixed == null ? Colors.grey : Colors.black)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: fixed != null ? percentage : 0.0,
                                        backgroundColor: Colors.grey.shade200,
                                        color: fixed != null ? barColor : Colors.grey.shade400,
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Gasto: R\$ ${spent.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        if (fixed != null)
                                          Text('Disponível: R\$ ${(fixed - spent).clamp(0.0, double.infinity).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        if (benefits.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Benefícios',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ...benefits.map((cat) {
                            final spent = summary[cat.id] ?? 0.0;
                            final fixed = cat.fixedValue;
                            final percentage = (fixed != null && fixed > 0) ? (spent / fixed).clamp(0.0, 1.0) : 0.0;
                            
                            Color barColor = Colors.blueAccent;
                            if (percentage >= 0.9) {
                              barColor = Colors.red;
                            } else if (percentage >= 0.7) {
                              barColor = Colors.orange;
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => showCategoryExpenses(cat, expenses),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          if (fixed != null)
                                            Text('${(percentage * 100).toStringAsFixed(0)}%'),
                                        ],
                                      ),
                                      if (fixed != null) ...[
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: percentage,
                                            backgroundColor: Colors.grey.shade200,
                                            color: barColor,
                                            minHeight: 8,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Utilizado: R\$ ${spent.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          if (fixed != null)
                                            Text('Disponível: R\$ ${(fixed - spent).clamp(0.0, double.infinity).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                        if (creditCards.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Faturas de Cartões',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ...creditCards.map((cat) {
                            final spent = summary[cat.id] ?? 0.0;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                onTap: () => showCategoryExpenses(cat, expenses),
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.blueAccent,
                                  child: Icon(Icons.credit_card, color: Colors.white),
                                ),
                                title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(cat.dueDay != null ? 'Vencimento: Dia ${cat.dueDay}' : 'Vencimento não configurado'),
                                trailing: Text(
                                  'R\$ ${spent.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
