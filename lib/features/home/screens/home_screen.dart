import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../finances/repositories/finances_repository.dart';
import '../../finances/models/category_model.dart';
import '../../finances/models/expense_model.dart';
import '../../finances/widgets/month_selector.dart';
import '../../../core/services/groq_service.dart';
import '../widgets/category_summary_card.dart';
import '../widgets/category_expenses_sheet.dart';
import '../../auth/screens/profile_screen.dart';
import 'notifications_screen.dart';
import '../../auth/repositories/auth_repository.dart';

final geminiInsightProvider = FutureProvider<String>((ref) async {
  final expenses = await ref.watch(currentMonthExpensesProvider.future);
  if (expenses.isEmpty) {
    return 'Adicione suas primeiras despesas para receber um insight financeiro.';
  }

  final summary = <String, Map<String, dynamic>>{};
  double totalGasto = 0.0;
  
  for (var e in expenses) {
    final catName = e.category?.name ?? 'Outros';
    final type = e.category?.type ?? 'outros';
    
    if (!summary.containsKey(catName)) {
      summary[catName] = {'amount': 0.0, 'type': type};
    }
    summary[catName]!['amount'] = (summary[catName]!['amount'] as double) + e.effectiveAmount;
    totalGasto += e.effectiveAmount;
  }

  final summaryStr = summary.entries
      .map((e) => '${e.key} (${e.value['type']}): R\$ ${(e.value['amount'] as double).toStringAsFixed(2)}')
      .join(', ');
      
  final promptData = 'Total Gasto no Mês: R\$ ${totalGasto.toStringAsFixed(2)}\nDetalhamento por categorias:\n$summaryStr';
  
  final groq = GroqService();
  return await groq.getFinancialInsight(promptData);
});

final expensesSummaryProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(currentMonthExpensesProvider).valueOrNull ?? [];
  final summary = <String, double>{};
  for (var e in expenses) {
    if (e.categoryId != null) {
      summary[e.categoryId!] = (summary[e.categoryId!] ?? 0) + e.effectiveAmount;
    }
  }
  return summary;
});

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 40 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _HeaderWidget()),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: MonthSelector(),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              const SliverToBoxAdapter(child: _InsightCardWidget()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              const SliverToBoxAdapter(child: _SectionTitle(title: "Resumo Rápido", emoji: "💸")),
              const SliverToBoxAdapter(child: _QuickSummaryWidget()),
              const _CategoryListsWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderWidget extends ConsumerWidget {
  const _HeaderWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final userName = userAsync.valueOrNull?.name.trim();
    final effectiveName = (userName != null && userName.isNotEmpty) ? userName : 'Usuário';
    final nameParts = effectiveName.split(RegExp(r'\s+'));
    final firstName = nameParts.first;
    
    String initials = "U";
    if (nameParts.length > 1) {
      initials = "${nameParts[0][0]}${nameParts[1][0]}".toUpperCase();
    } else if (nameParts[0].isNotEmpty) {
      initials = nameParts[0][0].toUpperCase();
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const FractionallySizedBox(
                  heightFactor: 0.85,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    child: ProfileScreen(),
                  ),
                ),
              );
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer],
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Olá, $firstName 👋",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: -0.5, fontSize: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  "Suas finanças em dia",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(child: Icon(Icons.notifications_outlined, color: Theme.of(context).textTheme.bodyLarge?.color, size: 24)),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary, 
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String emoji;
  const _SectionTitle({required this.title, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }
}

class _InsightCardWidget extends ConsumerWidget {
  const _InsightCardWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightAsync = ref.watch(geminiInsightProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 24,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: insightAsync.when(
                data: (insight) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Insight da IA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      insight,
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                    ),
                  ],
                ),
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Colors.white),
                )),
                error: (e, _) => Text('Erro ao gerar insight: $e', style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSummaryWidget extends ConsumerWidget {
  const _QuickSummaryWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(currentMonthExpensesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return expensesAsync.when(
      data: (expenses) {
        final total = expenses.fold<double>(0, (sum, e) => sum + e.effectiveAmount);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: [
                BoxShadow(
                  blurRadius: 16,
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.arrow_downward_rounded, color: Theme.of(context).colorScheme.error, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gastos deste Mês', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        'R\$ ${total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erro: $e'),
    );
  }
}

class _CategoryListsWidget extends ConsumerWidget {
  const _CategoryListsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final summary = ref.watch(expensesSummaryProvider);
    final expensesAsync = ref.watch(currentMonthExpensesProvider);

    return categoriesAsync.when(
      data: (categories) {
        final fixedCategories = categories.where((c) => c.type == 'fixa').toList();
        final variableCategories = categories.where((c) => c.type == 'variavel').toList();
        final creditCards = categories.where((c) => c.type == 'credito').toList();
        final benefits = categories.where((c) => c.type == 'beneficio').toList();
        final allExpenses = expensesAsync.valueOrNull ?? [];

        return SliverList(
          delegate: SliverChildListDelegate([
            if (variableCategories.isNotEmpty) ...[
              const _SectionTitle(title: "Acompanhamento de Limites", emoji: "📊"),
              _buildCategoryList(context, variableCategories, summary, allExpenses, Theme.of(context).colorScheme.tertiary),
            ],
            if (fixedCategories.isNotEmpty) ...[
              const _SectionTitle(title: "Despesas Fixas", emoji: "📌"),
              _buildCategoryList(context, fixedCategories, summary, allExpenses, Theme.of(context).colorScheme.secondary),
            ],
            if (benefits.isNotEmpty) ...[
              const _SectionTitle(title: "Benefícios", emoji: "🎁"),
              _buildCategoryList(context, benefits, summary, allExpenses, Theme.of(context).colorScheme.primary),
            ],
            if (creditCards.isNotEmpty) ...[
              const _SectionTitle(title: "Faturas de Cartões", emoji: "💳"),
              _buildCreditCardsList(context, creditCards, summary, allExpenses),
            ],
            const SizedBox(height: 120), // Espaço pro BottomNavigationBar
          ]),
        );
      },
      loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverToBoxAdapter(child: Text('Erro: $e')),
    );
  }

  Widget _buildCategoryList(BuildContext context, List<CategoryModel> categories, Map<String, double> summary, List<ExpenseModel> allExpenses, Color barColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: categories.map((cat) => CategorySummaryCard(
          category: cat,
          spent: summary[cat.id] ?? 0.0,
          barColor: barColor,
          onTap: () => showCategoryExpensesSheet(context, cat, allExpenses),
        )).toList(),
      ),
    );
  }

  Widget _buildCreditCardsList(BuildContext context, List<CategoryModel> creditCards, Map<String, double> summary, List<ExpenseModel> allExpenses) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: creditCards.map((cat) {
          final spent = summary[cat.id] ?? 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => showCategoryExpensesSheet(context, cat, allExpenses),
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.credit_card_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                    ),
                    title: Text(cat.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        cat.dueDay != null ? 'Vencimento: Dia ${cat.dueDay}' : 'Vencimento não configurado',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    trailing: Text(
                      'R\$ ${spent.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
