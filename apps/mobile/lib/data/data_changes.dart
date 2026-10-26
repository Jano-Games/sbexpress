import 'package:flutter/foundation.dart';

/// Goes up each time a flight, shipment, flyer or customer is deleted,
/// archived or restored. Screens the tab shell keeps alive (Home, Shipments,
/// Flights) listen and reload, so a removed row does not linger on a tab
/// that was not on screen.
final dataChanges = ValueNotifier<int>(0);

void notifyDataChanged() => dataChanges.value++;
