import 'package:flutter/widgets.dart';

import 'data/api/api_client.dart';
import 'data/repositories/customer_repository.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/repositories/finance_repository.dart';
import 'data/repositories/flight_repository.dart';
import 'data/repositories/flyer_repository.dart';
import 'data/repositories/media_repository.dart';
import 'data/repositories/review_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/shipment_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/session/session_controller.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.session,
    required this.shipments,
    required this.dashboard,
    required this.tasks,
    required this.review,
    required this.media,
    required this.flights,
    required this.flyers,
    required this.customers,
    required this.finance,
    required this.settings,
    required super.child,
  });

  final SessionController session;
  final ShipmentRepository shipments;
  final DashboardRepository dashboard;
  final TaskRepository tasks;
  final ReviewRepository review;
  final MediaRepository media;
  final FlightRepository flights;
  final FlyerRepository flyers;
  final CustomerRepository customers;
  final FinanceRepository finance;
  final SettingsRepository settings;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) throw StateError('AppScope missing');
    return scope;
  }

  factory AppScope.wired({
    required SessionController session,
    required ApiClient api,
    required Widget child,
  }) {
    return AppScope(
      session: session,
      shipments: ShipmentRepository(api),
      dashboard: DashboardRepository(api),
      tasks: TaskRepository(api),
      review: ReviewRepository(api),
      media: MediaRepository(api),
      flights: FlightRepository(api),
      flyers: FlyerRepository(api),
      customers: CustomerRepository(api),
      finance: FinanceRepository(api),
      settings: SettingsRepository(api),
      child: child,
    );
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
