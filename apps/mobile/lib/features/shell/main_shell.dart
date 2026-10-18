import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/models/session_user.dart';
import '../../widgets/ui.dart';
import '../admin/admin_home_screen.dart';
import '../hub/hub_home_screen.dart';
import '../more/more_screen.dart';
import '../shipments/shipments_screen.dart';
import '../tasks/tasks_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final user = scope.session.user;
    if (user == null) return const SizedBox.shrink();
    final pages = switch (user.role) {
      UserRole.hub => [
          HubHomeScreen(dashboard: scope.dashboard),
          ShipmentsScreen(role: user.role, shipments: scope.shipments),
          TasksScreen(role: user.role, tasks: scope.tasks),
          MoreScreen(user: user, session: scope.session),
        ],
      UserRole.admin => [
          AdminHomeScreen(dashboard: scope.dashboard),
          ShipmentsScreen(role: user.role, shipments: scope.shipments),
          TasksScreen(role: user.role, tasks: scope.tasks),
          MoreScreen(user: user, session: scope.session),
        ],
    };
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: AppBottomNav(index: _index, onChanged: (value) => setState(() => _index = value)),
    );
  }
}
