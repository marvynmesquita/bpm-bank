import 'package:flutter/material.dart';
import '../../finances/models/category_model.dart';
import '../../finances/models/expense_model.dart';

void showCategoryExpensesSheet(BuildContext context, CategoryModel cat, List<ExpenseModel> allExpenses) {
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
