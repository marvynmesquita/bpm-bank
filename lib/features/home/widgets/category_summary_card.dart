import 'package:flutter/material.dart';
import '../../finances/models/category_model.dart';
import '../../../core/theme/app_colors.dart';

class CategorySummaryCard extends StatelessWidget {
  final CategoryModel category;
  final double spent;
  final Color barColor;
  final VoidCallback onTap;

  const CategorySummaryCard({
    super.key,
    required this.category,
    required this.spent,
    required this.barColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fixed = category.fixedValue;
    final percentage = (fixed != null && fixed > 0) ? (spent / fixed).clamp(0.0, 1.0) : 0.0;
    
    // Acessibilidade e hierarquia: determinando a cor final com base no nível crítico
    Color finalColor = barColor;
    if (percentage >= 0.9) {
      finalColor = Theme.of(context).colorScheme.error;
    } else if (percentage >= 0.7) {
      finalColor = Colors.orangeAccent;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            splashColor: finalColor.withOpacity(0.1),
            highlightColor: finalColor.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderSection(category: category, fixed: fixed, percentage: percentage),
                  if (fixed != null) ...[
                    const SizedBox(height: 16),
                    _ProgressBar(percentage: percentage, finalColor: finalColor, isDark: isDark),
                  ],
                  const SizedBox(height: 16),
                  _DetailsSection(category: category, spent: spent, fixed: fixed),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Atomic Design: Subcomponentes ───

class _HeaderSection extends StatelessWidget {
  final CategoryModel category;
  final double? fixed;
  final double percentage;

  const _HeaderSection({
    required this.category,
    this.fixed,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              if (category.dueDay != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Vencimento: Dia ${category.dueDay}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (fixed != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(percentage * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double percentage;
  final Color finalColor;
  final bool isDark;

  const _ProgressBar({
    required this.percentage,
    required this.finalColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: percentage,
        backgroundColor: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF0F0F5),
        color: finalColor,
        minHeight: 10,
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final CategoryModel category;
  final double spent;
  final double? fixed;

  const _DetailsSection({
    required this.category,
    required this.spent,
    this.fixed,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = category.type == "beneficio" ? "Utilizado" : "Gasto";
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(typeLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              'R\$ ${spent.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.5),
            ),
          ],
        ),
        if (fixed != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Disponível', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                'R\$ ${(fixed! - spent).clamp(0.0, double.infinity).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
