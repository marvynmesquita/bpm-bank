import 'package:flutter/material.dart';
import '../tabs/shopping_tab.dart';
import '../tabs/todos_tab.dart';
import '../tabs/appointments_tab.dart';

class OrganizationScreen extends StatelessWidget {
  const OrganizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Organização'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.shopping_cart), text: 'Compras'),
              Tab(icon: Icon(Icons.check_box), text: 'Afazeres'),
              Tab(icon: Icon(Icons.calendar_month), text: 'Agenda'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ShoppingTab(),
            TodosTab(),
            AppointmentsTab(),
          ],
        ),
      ),
    );
  }
}
