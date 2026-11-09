import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/flight_route.dart';
import '../../data/models/hub_flight.dart' show FlightDay;
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart' show FieldLabel;
import '../../widgets/ui.dart';

final _flightNumber = RegExp(r'^(?:[A-Z]{2}|[A-Z]\d|\d[A-Z]|[A-Z]{3})\d{1,4}$');
final _clock = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// "mu5842 + MU2035" or "MU5842, MU2035" → ["MU5842", "MU2035"].
List<String> flightNumbers(String input) => [
      for (final part in input.split(RegExp('[+,]')))
        if (part.replaceAll(RegExp(r'\s+'), '').isNotEmpty)
          part.replaceAll(RegExp(r'\s+'), '').toUpperCase()
    ];

/// The first part that is not an airline flight number such as BG305.
String? badFlightNumber(List<String> numbers) {
  for (final number in numbers) {
    if (!_flightNumber.hasMatch(number)) return number;
  }
  return null;
}

/// "BG305" from the reference "BG305-20261024-ab12cd"; "+" stays.
String flightNumberOf(String code) =>
    code.replaceFirst(RegExp(r'-\d{8}-[a-z0-9]+$', caseSensitive: false), '');

/// A 24-hour "09:40".
bool isClock(String value) => _clock.hasMatch(value.trim());

/// "PVG Shanghai" → PVG and Shanghai; "Shanghai" alone has no code.
({String iata, String city}) parseStop(String text) {
  final value = text.trim();
  final match = RegExp(r'^([A-Z]{3})(?:\s+(.+))?$').firstMatch(value);
  if (match == null) return (iata: '', city: value);
  return (iata: match[1]!, city: (match[2] ?? '').trim());
}

/// Where a connection changes planes, "PVG Shanghai, KMG Kunming".
String stopsOfLegs(List<FlightLeg> legs) => [
      for (final leg in legs.take(legs.length - 1))
        [leg.toIata, leg.toCity].where((part) => part.isNotEmpty).join(' ')
    ].where((stop) => stop.isNotEmpty).join(', ');

String _shiftDay(String iso, int days) {
  final day = DateTime.utc(int.parse(iso.substring(0, 4)),
          int.parse(iso.substring(5, 7)), int.parse(iso.substring(8, 10)))
      .add(Duration(days: days));
  return '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

int _daysBetween(String from, String to) =>
    DateTime.parse(to).difference(DateTime.parse(from)).inDays;

/// The legs to save. [base] legs (from the schedule, or the flight being
/// edited) stay when they are the same flights in the same order: their
/// airports are kept, their days move with [date], and the typed first
/// departure, last landing and stops go on top. Otherwise each number
/// becomes a hand-entered leg.
List<FlightLeg> buildLegs({
  required List<String> numbers,
  required String date,
  required String depTime,
  required String arrTime,
  required String stops,
  List<FlightLeg> base = const [],
}) {
  var same = base.length == numbers.length;
  for (var i = 0; same && i < numbers.length; i++) {
    same = base[i].code.toUpperCase() == numbers[i];
  }
  final firstDay = same ? base.first.date : null;
  final shift = firstDay == null ? 0 : _daysBetween(firstDay, date);
  final legs = [
    for (var i = 0; i < numbers.length; i++)
      if (same)
        base[i].copyWith(
            date: base[i].date == null ? date : _shiftDay(base[i].date!, shift))
      else
        FlightLeg(code: numbers[i], date: date)
  ];
  final typed = [
    for (final stop in stops.split(','))
      if (stop.trim().isNotEmpty) stop.trim()
  ];
  for (var i = 0; i < legs.length - 1 && i < typed.length; i++) {
    final stop = parseStop(typed[i]);
    legs[i] = legs[i].copyWith(toIata: stop.iata, toCity: stop.city);
    legs[i + 1] =
        legs[i + 1].copyWith(fromIata: stop.iata, fromCity: stop.city);
  }
  legs[0] = legs[0].copyWith(depTime: depTime.trim());
  legs[legs.length - 1] = legs.last.copyWith(arrTime: arrTime.trim());
  return legs;
}

/// "0940" → "09:40" while typing.
class ClockTimeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}:${digits.substring(2)}';
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

enum LookupState { idle, busy, found, partial, off, failed }

/// Number, date, times and stops of a flight, and what the airline schedule
/// says about them. Shared by New flight and Edit flight.
class ItineraryController extends ChangeNotifier {
  ItineraryController(
      {String number = '',
      this.date,
      String depTime = '',
      String arrTime = '',
      String stops = '',
      this.baseLegs = const []})
      : number = TextEditingController(text: number),
        depTime = TextEditingController(text: depTime),
        arrTime = TextEditingController(text: arrTime),
        stops = TextEditingController(text: stops) {
    for (final field in [this.number, this.depTime, this.arrTime, this.stops]) {
      field.addListener(notifyListeners);
    }
  }

  final TextEditingController number, depTime, arrTime, stops;
  String? date;

  /// The legs the flight has now; kept when the number stays the same.
  final List<FlightLeg> baseLegs;

  /// Save was tried, so missing fields show as missing.
  var showErrors = false;

  /// Saving; the form leaving the number field looks nothing up.
  var pauseLookups = false;
  var _disposed = false;

  var state = LookupState.idle;
  RouteLookup? result;
  String? lookupError;
  String? _lookedUp;
  String? _resultKey;

  /// What the schedule last filled in, so it may fill again over its own
  /// values but never over typed ones.
  ({String dep, String arr, String stops})? _filled;

  List<String> get numbers => flightNumbers(number.text);

  /// The numbers and date to look up; null until both are usable.
  String? get lookupKey {
    final all = numbers;
    if (all.isEmpty || date == null || badFlightNumber(all) != null) {
      return null;
    }
    return '${all.join('+')}@$date';
  }

  /// The last lookup was for the numbers and date in the form now.
  bool get resultIsCurrent =>
      result != null && lookupKey != null && _resultKey == lookupKey;

  /// The schedule's legs, when every one was found for these numbers.
  List<FlightLeg>? get scheduleLegs {
    final found = result;
    if (found == null || !found.found || _resultKey != lookupKey) return null;
    return [for (final leg in found.legs) leg.toLeg()];
  }

  /// The schedule has times that differ from the typed ones.
  bool get timesDiffer {
    final found = result;
    if (found == null || _resultKey != lookupKey) return false;
    return (found.depTime != null && found.depTime != depTime.text) ||
        (found.arrTime != null && found.arrTime != arrTime.text);
  }

  void setDate(String? value) {
    date = value;
    notifyListeners();
  }

  /// Looks the flight up. [auto] skips a lookup already made for the same
  /// numbers and date.
  Future<void> lookUp(BuildContext context, {bool auto = false}) async {
    final key = lookupKey;
    if (key == null || state == LookupState.busy) return;
    if (auto && (key == _lookedUp || pauseLookups)) return;
    final flights = AppScope.of(context).flights;
    _lookedUp = key;
    state = LookupState.busy;
    lookupError = null;
    notifyListeners();
    try {
      final found = await flights.lookupRoute(numbers.join('+'), date!);
      if (key != lookupKey) {
        state = LookupState.idle;
        return;
      }
      result = found;
      _resultKey = key;
      state = !found.configured
          ? LookupState.off
          : found.found
              ? LookupState.found
              : LookupState.partial;
      if (found.configured) _fill(found, force: false);
    } on ApiException catch (error) {
      state = LookupState.failed;
      lookupError = switch (error.status) {
        404 => tr('The server needs an update to look up flight times.'),
        // The flight data plan allows about one call a second.
        429 || 503 => tr(
            'The flight schedule is busy. Wait a few seconds, then tap Look again.'),
        _ => error.message,
      };
    } on FormatException {
      // A server that does not know this lookup answers with something else.
      state = LookupState.failed;
      lookupError = tr('The server needs an update to look up flight times.');
    } finally {
      notifyListeners();
    }
  }

  /// Puts the schedule's times in, over typed ones too.
  void useScheduleTimes() {
    final found = result;
    if (found != null) _fill(found, force: true);
  }

  void _fill(RouteLookup found, {required bool force}) {
    final last = _filled;
    bool free(TextEditingController field, String? before) =>
        force || field.text.trim().isEmpty || field.text == before;
    if (found.depTime != null && free(depTime, last?.dep)) {
      depTime.text = found.depTime!;
    }
    if (found.arrTime != null && free(arrTime, last?.arr)) {
      arrTime.text = found.arrTime!;
    }
    final via = found.legs.length > 1
        ? stopsOfLegs([for (final leg in found.legs) leg.toLeg()])
        : '';
    if (via.isNotEmpty && free(stops, last?.stops)) stops.text = via;
    _filled = (dep: depTime.text, arr: arrTime.text, stops: stops.text);
  }

  /// The first thing missing or wrong, in the order of the form.
  String? problem() {
    final all = numbers;
    if (all.isEmpty) return tr('Enter the airline flight number.');
    final bad = badFlightNumber(all);
    if (bad != null) {
      return tr('"{number}" is not a flight number. Write it like BG305.',
          {'number': bad});
    }
    if (date == null) return tr('Choose a date.');
    if (depTime.text.trim().isEmpty) return tr('Choose the departure time.');
    if (!isClock(depTime.text)) {
      return tr('Write the departure time like 09:40.');
    }
    if (arrTime.text.trim().isEmpty) return tr('Choose the landing time.');
    if (!isClock(arrTime.text)) return tr('Write the landing time like 17:25.');
    return null;
  }

  /// The legs to send; [problem] must be null first.
  List<FlightLeg> legs() => buildLegs(
      numbers: numbers,
      date: date!,
      depTime: depTime.text,
      arrTime: arrTime.text,
      stops: numbers.length > 1 ? stops.text : '',
      base: scheduleLegs ?? baseLegs);

  @override
  void notifyListeners() {
    // A lookup may answer after the screen has closed.
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final field in [number, depTime, arrTime, stops]) {
      field.dispose();
    }
    super.dispose();
  }
}

/// "Thu, 20 Nov 2026".
String flightDateLabel(String iso) {
  final day = FlightDay.parse(iso);
  return day == null ? iso : '${day.shortLabel} ${iso.substring(0, 4)}';
}

/// The number with its example, the date, the schedule lookup, the two
/// times and, for a connection, where it changes planes.
class ItineraryFields extends StatefulWidget {
  const ItineraryFields(
      {super.key, required this.controller, this.lookUpOnChange = true});
  final ItineraryController controller;

  /// Looks the flight up by itself once the number and date are in.
  final bool lookUpOnChange;

  @override
  State<ItineraryFields> createState() => _ItineraryFieldsState();
}

class _ItineraryFieldsState extends State<ItineraryFields> {
  final _numberFocus = FocusNode();

  ItineraryController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _numberFocus.addListener(() {
      if (!_numberFocus.hasFocus) _autoLookUp();
    });
  }

  @override
  void dispose() {
    _numberFocus.dispose();
    super.dispose();
  }

  void _autoLookUp() {
    if (widget.lookUpOnChange && mounted) _c.lookUp(context, auto: true);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = _c.date == null ? null : DateTime.tryParse(_c.date!);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !mounted) return;
    _c.setDate('${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}');
    _autoLookUp();
  }

  Future<void> _pickTime(TextEditingController field) async {
    final parts = isClock(field.text) ? field.text.split(':') : null;
    final picked = await showTimePicker(
        context: context,
        initialTime: parts == null
            ? const TimeOfDay(hour: 9, minute: 0)
            : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!));
    if (picked == null) return;
    field.text = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final numbers = _c.numbers;
          final connection = numbers.length > 1;
          final errors = _c.showErrors;
          String? missing(TextEditingController field) {
            if (!errors) return null;
            if (field.text.trim().isEmpty) return tr('Required');
            return isClock(field.text) ? null : tr('Use 24-hour time, 09:40');
          }

          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                    key: const Key('flight-number'),
                    controller: _c.number,
                    focusNode: _numberFocus,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _autoLookUp(),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                        labelText: tr('Airline flight number'),
                        hintText: 'BG305',
                        helperText: tr(
                            'e.g. BG305. A connection: join both with +, like MU5842+MU2035'),
                        helperMaxLines: 3,
                        errorText:
                            errors && numbers.isEmpty ? tr('Required') : null)),
                if (connection) ...[
                  const SizedBox(height: 10),
                  _LegChips(numbers: numbers),
                ],
                const SizedBox(height: 14),
                FieldLabel(tr('Date')),
                AppButton(
                    key: const Key('flight-date'),
                    label: _c.date == null
                        ? tr('Choose date')
                        : flightDateLabel(_c.date!),
                    icon: Icons.calendar_today_outlined,
                    kind: AppButtonKind.quiet,
                    onPressed: _pickDate),
                if (errors && _c.date == null)
                  Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Text(tr('Required'),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.danger))),
                const SizedBox(height: 14),
                ScheduleCard(controller: _c, onFind: () => _c.lookUp(context)),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: _TimeField(
                          fieldKey: const Key('flight-dep'),
                          controller: _c.depTime,
                          label: tr('Departs'),
                          error: missing(_c.depTime),
                          onPick: () => _pickTime(_c.depTime))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _TimeField(
                          fieldKey: const Key('flight-arr'),
                          controller: _c.arrTime,
                          label: tr('Lands'),
                          error: missing(_c.arrTime),
                          onPick: () => _pickTime(_c.arrTime))),
                ]),
                const SizedBox(height: 6),
                Text(
                    connection
                        ? tr(
                            'Local time at each airport: when the first flight leaves and the last one lands.')
                        : tr('Local time at each airport.'),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted, height: 1.4)),
                if (connection) ...[
                  const SizedBox(height: 14),
                  TextField(
                      key: const Key('flight-stop'),
                      controller: _c.stops,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                          labelText: tr('Changes planes at (optional)'),
                          hintText: 'PVG Shanghai',
                          helperText: tr(
                              'Shows on the flight as "via Shanghai". For two stops, put a comma between them.'),
                          helperMaxLines: 3)),
                ],
              ]);
        });
  }
}

class _LegChips extends StatelessWidget {
  const _LegChips({required this.numbers});
  final List<String> numbers;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    for (var i = 0; i < numbers.length; i++) {
      if (i > 0) {
        parts.add(const Icon(Icons.arrow_forward_rounded,
            size: 16, color: AppColors.muted));
      }
      parts.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(999)),
          child: Text(numbers[i],
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryInk))));
    }
    parts.add(Text(
        trn(numbers.length, '{n} flight, one ticket',
            '{n} flights, one ticket'),
        style: const TextStyle(fontSize: 12, color: AppColors.muted)));
    return Wrap(
        key: const Key('flight-legs'),
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: parts);
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField(
      {required this.fieldKey,
      required this.controller,
      required this.label,
      required this.onPick,
      this.error});
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final VoidCallback onPick;
  final String? error;

  @override
  Widget build(BuildContext context) => TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [ClockTimeFormatter()],
      style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
          labelText: label,
          hintText: '--:--',
          errorText: error,
          suffixIcon: IconButton(
              tooltip: tr('Pick a time'),
              onPressed: onPick,
              icon: const Icon(Icons.schedule_rounded, size: 20))));
}

/// What the airline schedule says, with Find times.
class ScheduleCard extends StatelessWidget {
  const ScheduleCard(
      {super.key, required this.controller, required this.onFind});
  final ItineraryController controller;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ready = c.lookupKey != null;
    final found = c.result;
    var state = c.state;
    // A lookup for numbers or a date that has since changed no longer applies.
    if (!c.resultIsCurrent &&
        state != LookupState.busy &&
        state != LookupState.failed) {
      state = LookupState.idle;
    }
    final (Color background, Color foreground, IconData icon) = switch (state) {
      LookupState.found => (
          AppColors.okSoft,
          AppColors.ok,
          Icons.check_circle_outline_rounded
        ),
      LookupState.partial || LookupState.off || LookupState.failed => (
          AppColors.accentSoft,
          AppColors.accentInk,
          Icons.info_outline_rounded
        ),
      _ => (
          AppColors.primarySoft,
          AppColors.primaryInk,
          Icons.travel_explore_rounded
        ),
    };
    final numbers = c.numbers.join(' + ');
    final (String title, String? body) = switch (state) {
      LookupState.idle => (
          tr('Times from the airline schedule'),
          ready
              ? tr('Tap Find times to fill them in from the number and date.')
              : tr('Enter the flight number and date to look up the times.')
        ),
      LookupState.busy => (
          tr('Looking up {number}', {'number': numbers}),
          tr('Checking the airline schedule.')
        ),
      LookupState.found => (
          tr('Found on the airline schedule'),
          c.timesDiffer
              ? tr('Your times are different from the schedule.')
              : tr('The times are filled in. Check them before you save.')
        ),
      LookupState.partial => (
          tr('Not on the schedule: {list}',
              {'list': found!.missing.join(', ')}),
          tr('Check the number and date, or type the times yourself.')
        ),
      LookupState.off => (
          tr('Automatic times are not set up'),
          tr('The server has no flight data key yet. Type the times yourself.')
        ),
      LookupState.failed => (
          tr('Could not look up the times'),
          c.lookupError,
        ),
    };
    final legs = state == LookupState.found || state == LookupState.partial
        ? [
            for (final leg in found!.legs)
              if (leg.found) leg
          ]
        : const <RouteLookupLeg>[];
    final action = switch (state) {
      LookupState.idle => (
          tr('Find times'),
          onFind,
          const Key('schedule-find')
        ),
      LookupState.found when c.timesDiffer => (
          tr('Use these times'),
          c.useScheduleTimes,
          const Key('schedule-use')
        ),
      LookupState.partial || LookupState.failed => (
          tr('Look again'),
          onFind,
          const Key('schedule-find')
        ),
      _ => null,
    };
    return Semantics(
        liveRegion: true,
        child: Container(
            key: const Key('schedule-card'),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
                color: background, borderRadius: BorderRadius.circular(14)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: state == LookupState.busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: foreground))
                            : Icon(icon, size: 19, color: foreground)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                  color: foreground)),
                          for (final leg in legs)
                            Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text.rich(_legLine(leg, c.date),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ]))),
                          if (body != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(body,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: AppColors.inkSoft))),
                        ])),
                  ]),
                  if (action != null) ...[
                    const SizedBox(height: 10),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                            key: action.$3,
                            onPressed: ready ? action.$2 : null,
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                backgroundColor: AppColors.card,
                                minimumSize: const Size(48, 44),
                                side: const BorderSide(color: AppColors.field),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                textStyle: const TextStyle(
                                    fontFamily: 'HindSiliguri',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            icon: Icon(
                                state == LookupState.found
                                    ? Icons.schedule_rounded
                                    : Icons.search_rounded,
                                size: 18),
                            label: Text(action.$1))),
                  ],
                ])));
  }
}

/// "MU5842 · PEK 09:40 → PVG 11:55", with the day when it is another day.
/// The arrow is an icon: the app's font has no arrow character.
TextSpan _legLine(RouteLookupLeg leg, String? date) {
  String end(String iata, String city, String? time) => [
        iata.isNotEmpty ? iata : city,
        time ?? '--:--',
      ].where((part) => part.isNotEmpty).join(' ');
  final day = leg.date != date ? ' · ${flightDateLabel(leg.date)}' : '';
  return TextSpan(children: [
    TextSpan(
        text: '${leg.code} · ${end(leg.fromIata, leg.fromCity, leg.depTime)} '),
    const WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Icon(Icons.arrow_forward_rounded,
            size: 14, color: AppColors.muted)),
    TextSpan(text: ' ${end(leg.toIata, leg.toCity, leg.arrTime)}$day'),
  ]);
}
