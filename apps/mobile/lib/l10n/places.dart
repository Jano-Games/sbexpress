import 'l10n.dart';

const _placeNames = {
  'chengdu': 'Chengdu',
  'ctu': 'Chengdu',
  'tfu': 'Chengdu',
  'dhaka': 'Dhaka',
  'dac': 'Dhaka',
  'kunming': 'Kunming',
  'kmg': 'Kunming',
  'guangzhou': 'Guangzhou',
  'can': 'Guangzhou',
  'chittagong': 'Chattogram',
  'cgp': 'Chattogram',
};

/// Bangla name for common airports; other places stay as the server sent them.
String banglaPlace(String? place, {required String fallback}) {
  if (place == null || place.trim().isEmpty) return fallback;
  final name = _placeNames[place.trim().toLowerCase()];
  return name == null ? place.trim() : tr(name);
}
