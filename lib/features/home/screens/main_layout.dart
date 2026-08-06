import 'package:flutter/material.dart';
import '../../finances/screens/add_expense_screen.dart';
import '../../finances/screens/dashboard_screen.dart';
import 'home_screen.dart';
import '../../organization/screens/organization_screen.dart';
import '../../finances/screens/loans_screen.dart';
import '../../finances/screens/add_loan_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const DashboardScreen(),
    const OrganizationScreen(),
    const LoansScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _screens[_currentIndex],
      floatingActionButton: _buildFAB(context),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget? _buildFAB(BuildContext context) {
    if (_currentIndex == 3) {
      return _customFAB(
        context: context,
        label: 'Empréstimo',
        icon: Icons.handshake_rounded,
        gradient: const LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFFF9800)]),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddLoanScreen()),
        ),
      );
    } else if (_currentIndex == 0 || _currentIndex == 1) {
      return _customFAB(
        context: context,
        label: 'Nova Adição',
        icon: Icons.add_circle_outline_rounded,
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.primary],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
        ),
      );
    }
    return null;
  }

  Widget _customFAB({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.last.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
          items: [
            _navItem(Icons.home_rounded, 'Home'),
            _navItem(Icons.pie_chart_rounded, 'Dashboard'),
            _navItem(Icons.check_box_rounded, 'Tarefas'),
            _navItem(Icons.credit_score_rounded, 'Empréstimos'),
          ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData icon, String label) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 4),
        child: Icon(icon, size: 24),
      ),
      activeIcon: Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 4),
        child: Icon(icon, size: 26),
      ),
      label: label,
    );
  }
}

