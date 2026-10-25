import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/models/session_user.dart';
import '../../widgets/ui.dart';
import '../admin/admin_home_screen.dart';
import '../hub/hub_home_screen.dart';
import '../more/more_screen.dart';
import '../shipments/shipments_screen.dart';
import '../tasks/tasks_screen.dart';
import '../flights/flights_screen.dart';
import '../flights/hub_flights_screen.dart';
import '../finance/finance_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;
  final _visited = <int>{0};

  void _go(int value) {
    FocusScope.of(context).unfocus();
    setState(() {
      _visited.add(value);
      _index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final user = scope.session.user;
    if (user == null) return const SizedBox.shrink();
    final pages = switch (user.role) {
      UserRole.hub => [
          HubHomeScreen(
              dashboard: scope.dashboard,
              onOpenShipments: () => _go(1),
              onOpenFlights: () => _go(2)),
          ShipmentsScreen(role: user.role, shipments: scope.shipments),
          const HubFlightsScreen(root: true),
          TasksScreen(role: user.role, tasks: scope.tasks),
          MoreScreen(user: user, session: scope.session),
        ],
      UserRole.admin => [
          AdminHomeScreen(
              dashboard: scope.dashboard,
              onOpenShipments: () => _go(1),
              onOpenFinance: () => _go(3)),
          ShipmentsScreen(role: user.role, shipments: scope.shipments),
          const FlightsScreen(root: true),
          const FinanceScreen(root: true),
          MoreScreen(user: user, session: scope.session),
        ],
    };
    return Scaffold(
      body: IndexedStack(index: _index, children: [
        for (var i = 0; i < pages.length; i++)
          _visited.contains(i) ? pages[i] : const SizedBox.shrink()
      ]),
      bottomNavigationBar: AppBottomNav(
          index: _index, admin: user.role == UserRole.admin, onChanged: _go),
    );
  }
}
