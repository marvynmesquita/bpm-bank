import 'package:flutter/material.dart';
import '../../finances/screens/add_expense_screen.dart';
import '../../finances/screens/dashboard_screen.dart';
import 'home_screen.dart';
import '../../auth/screens/profile_screen.dart';
import '../../finances/screens/categories_screen.dart';
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
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      floatingActionButton: _currentIndex == 3
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddLoanScreen()),
                );
              },
              backgroundColor: Colors.orange,
              icon: const Icon(Icons.handshake, color: Colors.white),
              label: const Text('Empréstimo', style: TextStyle(color: Colors.white)),
            )
          : _currentIndex == 0 || _currentIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                    );
                  },
                  backgroundColor: Theme.of(context).primaryColor,
                  icon: const Icon(Icons.money_off, color: Colors.white),
                  label: const Text('Despesa', style: TextStyle(color: Colors.white)),
                )
              : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Necessário para 5 abas
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            activeIcon: Icon(Icons.pie_chart),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box_outlined),
            activeIcon: Icon(Icons.check_box),
            label: 'Tarefas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_score_outlined),
            activeIcon: Icon(Icons.credit_score),
            label: 'Empréstimos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
