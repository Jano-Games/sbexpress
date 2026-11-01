import 'models/flight.dart';
import 'models/workspace.dart';

/// The rates a new order starts with: the flight's own, else the default.
class OrderRates {
  const OrderRates(
      {required this.kgRate,
      required this.currency,
      required this.pieces,
      this.flight});

  /// Null when neither the flight nor the default has a rate per kg.
  final double? kgRate;
  final String currency;
  final Map<String, double> pieces;

  /// The flight the kg rate comes from; null for the default.
  final String? flight;

  /// The piece price for [category], whatever its case: the server may send
  /// "mobile" while the rates say "Mobile".
  double? piece(String category) => pieceRate(pieces, category);
}

double? pieceRate(Map<String, double> rates, String category) {
  final lower = category.trim().toLowerCase();
  for (final entry in rates.entries) {
    if (entry.key.trim().toLowerCase() == lower) return entry.value;
  }
  return null;
}

OrderRates orderRates(SettingsSnapshot settings, FlightSummary? flight) {
  final own = flight?.ownRates;
  if (own == null) {
    return OrderRates(
        kgRate: settings.kgRate,
        currency: settings.kgRateCurrency,
        pieces: settings.pcsRates);
  }
  final ownNames = {for (final name in own.pcsRates.keys) name.toLowerCase()};
  return OrderRates(
      kgRate: own.kgRate,
      currency: own.currency,
      pieces: {
        for (final entry in settings.pcsRates.entries)
          if (!ownNames.contains(entry.key.toLowerCase()))
            entry.key: entry.value,
        ...own.pcsRates,
      },
      flight: flight!.displayCode);
}
