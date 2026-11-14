import 'package:flutter/widgets.dart';

import '../../data/models/app_notification.dart';
import '../../data/models/session_user.dart';
import '../admin/admin_shipment_screen.dart';
import '../flights/flight_detail_screen.dart';
import '../flights/hub_flights_screen.dart';
import '../shipments/shipment_process_screen.dart';
import '../sorting/approve_customer_screen.dart';
import '../sorting/sort_customer_screen.dart';
import '../sorting/sort_flight_screen.dart';

/// The screen a tap on [note] opens, or null when there is nothing to open.
/// Push to phones later opens the same screens.
Widget? notificationTarget(AppNotification note, UserRole role) {
  final flight = note.flightCode;
  final customer = note.customerCode;
  final order = note.shipmentCode;
  final admin = role == UserRole.admin;
  switch (note.event) {
    case 'sort_waiting' || 'delivered' when flight != null && customer != null:
      return admin
          ? ApproveCustomerScreen(flightCode: flight, customer: customer)
          : SortCustomerScreen(flightCode: flight, customer: customer);
    case 'sort_sent_back' || 'sort_approved'
        when flight != null && customer != null:
      return admin
          ? ApproveCustomerScreen(flightCode: flight, customer: customer)
          : SortCustomerScreen(flightCode: flight, customer: customer);
    case 'orders_received' when flight != null:
      return SortFlightScreen(flightCode: flight);
    case 'problem' when order != null:
      return admin
          ? AdminShipmentScreen(code: order)
          : ShipmentProcessScreen(code: order);
  }
  if (flight != null) {
    return admin
        ? FlightDetailScreen(code: flight)
        : HubFlightDetailScreen(code: flight);
  }
  if (order != null) {
    return admin
        ? AdminShipmentScreen(code: order)
        : ShipmentProcessScreen(code: order);
  }
  return null;
}
