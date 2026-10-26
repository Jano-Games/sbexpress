import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer.dart';
import '../../data/models/flight.dart';
import '../../data/models/workspace.dart';
import '../../data/uploads/photo_upload.dart';
import '../../data/uploads/quick_uploads.dart';
import '../../data/uploads/upload_queue.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart'
    show CategoryChip, LetterAvatar, heroSoft, shortDay;
import '../../widgets/quick_parts.dart';
import '../../widgets/team_parts.dart'
    show FooterActions, LabeledField, PairRow, fieldSign;
import '../../widgets/ui.dart';
import '../admin/money_format.dart';
import '../customers/customer_form_screen.dart';
import 'booking_done_screen.dart';

/// New shipment on one page: customer, flight, what is inside, weight and
/// charge, how the customer pays, then photos and a note.
class IntakeScreen extends StatefulWidget {
  const IntakeScreen({super.key, this.lockedFlightCode, this.pickPhotos});

  /// The flight the booking starts on, e.g. when opened from a flight.
  final String? lockedFlightCode;

  /// Picks photos from the camera or the gallery. Tests replace it.
  final Future<List<PickedPhoto>> Function(FileSource source)? pickPhotos;

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

/// One model of a device category and how many pieces of it.
class _ModelRow {
  _ModelRow() : model = TextEditingController();
  final TextEditingController model;
  int count = 1;
}

/// A device category on the booking: its models, piece price and photos.
class _DeviceDraft {
  _DeviceDraft({required double rate})
      : rate = TextEditingController(text: rate == 0 ? '' : _number(rate)),
        models = [_ModelRow()];

  final TextEditingController rate;
  final List<_ModelRow> models;
  final photos = <PickedPhoto>[];

  int get count => models.fold(0, (sum, row) => sum + row.count);
  double get rateValue => double.tryParse(rate.text.trim()) ?? 0;

  /// One unit per piece with its model; no serial or IMEI is asked for.
  IntakePiece toPiece(String category, String currency) => IntakePiece(
          category: category,
          count: count,
          rate: rateValue,
          currency: currency,
          units: [
            for (final row in models)
              for (var i = 0; i < row.count; i++)
                (model: row.model.text.trim(), serial: ''),
          ]);

  void dispose() {
    rate.dispose();
    for (final row in models) {
      row.model.dispose();
    }
  }
}

/// The server keeps at most 20 units per device category.
const _maxPieces = 20;

const _newCustomer = '\u0000new';

class _IntakeScreenState extends State<IntakeScreen> {
  List<CustomerSummary> _customers = const [];
  List<FlightSummary> _flights = const [];
  List<String> _categories = const [];
  Map<String, double> _pcsRates = const {};
  String? _error;
  String? _formError;
  var _loading = true;
  var _busy = false;
  var _addingCategory = false;
  var _savingCategory = false;

  String? _supplier;
  final _picked = <String>{};
  final _categoryName = TextEditingController();
  final _kg = TextEditingController();
  final _rate = TextEditingController();
  final _description = TextEditingController();
  var _currency = 'BDT';

  /// `invoice` (after delivery) or `monthly`; the customer's usual way until
  /// the operator picks one.
  var _terms = 'invoice';
  var _termsChosen = false;
  String? _flight;

  /// "Decide later" was tapped, or a flight was chosen.
  var _flightDecided = false;
  String? _flyer;
  final _devices = <String, _DeviceDraft>{};
  final _parcelPhotos = <PickedPhoto>[];

  @override
  void initState() {
    super.initState();
    _flight = widget.lockedFlightCode;
    _flightDecided = _flight != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _categoryName.dispose();
    _kg.dispose();
    _rate.dispose();
    _description.dispose();
    for (final device in _devices.values) {
      device.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = AppScope.of(context);
      final customers = await scope.customers.list();
      final flights = await scope.flights.list();
      final categories = await scope.settings.categories();
      final settings = await scope.settings.current();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _flights = [
          for (final flight in flights)
            if (flight.status == 'upcoming') flight
        ];
        _categories = categories;
        _pcsRates = settings.pcsRates;
        // A flight chosen before the booking opened brings its only flyer.
        final flyers = _selectedFlight?.flyers ?? const <String>[];
        if (_flyer == null && flyers.length == 1) _flyer = flyers.first;
      });
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  FlightSummary? get _selectedFlight {
    for (final flight in _flights) {
      if (flight.code == _flight) return flight;
    }
    return null;
  }

  CustomerSummary? get _selectedCustomer {
    for (final customer in _customers) {
      if (customer.code == _supplier) return customer;
    }
    return null;
  }

  double get _kgValue => double.tryParse(_kg.text.trim()) ?? 0;
  double get _rateValue => double.tryParse(_rate.text.trim()) ?? 0;
  String get _sign => _currency == 'CNY' ? '¥' : '৳';

  /// Device categories in the order they were picked.
  List<(String, _DeviceDraft)> get _deviceList => [
        for (final name in _picked)
          if (_devices[name] case final device?) (name, device)
      ];

  double get _total => _deviceList.fold(_kgValue * _rateValue,
      (sum, entry) => sum + entry.$2.count * entry.$2.rateValue);

  /// Done state of the five numbered parts.
  List<bool> get _done => [
        _supplier != null,
        _flightDecided,
        _picked.isNotEmpty,
        _total > 0,
        _termsChosen,
      ];

  StepMark _mark(int index) {
    final done = _done;
    if (done[index]) return StepMark.done;
    return done.indexOf(false) == index ? StepMark.current : StepMark.waiting;
  }

  Future<void> _pickCustomer() async {
    final value = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _PickerSheet(
            title: tr('Choose a customer'),
            options: [
              for (final customer in _customers)
                (
                  value: customer.code,
                  title: customer.name,
                  subtitle: '${customer.code} · ${customer.phone}'
                ),
            ],
            selected: _supplier));
    if (!mounted || value == null) return;
    if (value == _newCustomer) return _addCustomer();
    setState(() {
      _supplier = value;
      _formError = null;
      if (!_termsChosen) _terms = _usualTerms(_selectedCustomer);
    });
  }

  /// Monthly customers go on the monthly bill; everyone else pays after
  /// delivery.
  static String _usualTerms(CustomerSummary? customer) =>
      customer?.terms == 'monthly' ? 'monthly' : 'invoice';

  /// Opens the customer form and picks the customer it created.
  Future<void> _addCustomer() async {
    final before = {for (final customer in _customers) customer.code};
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CustomerFormScreen()));
    if (created != true || !mounted) return;
    await _load();
    if (!mounted) return;
    final fresh = [
      for (final customer in _customers)
        if (!before.contains(customer.code)) customer
    ];
    if (fresh.length == 1) {
      setState(() {
        _supplier = fresh.single.code;
        if (!_termsChosen) _terms = _usualTerms(fresh.single);
      });
    }
  }

  void _chooseFlight(String? code) {
    setState(() {
      _flight = code;
      _flightDecided = true;
      final flyers = _selectedFlight?.flyers ?? <String>[];
      _flyer = flyers.length == 1 ? flyers.first : null;
    });
  }

  bool _isPiece(String name) =>
      _pcsRates.containsKey(name) ||
      RegExp('mobile|laptop|drone', caseSensitive: false).hasMatch(name);

  void _toggleCategory(String name) {
    setState(() {
      _formError = null;
      if (_picked.contains(name)) {
        _picked.remove(name);
        _devices.remove(name)?.dispose();
      } else {
        _picked.add(name);
        if (_isPiece(name)) {
          _devices[name] = _DeviceDraft(rate: _pcsRates[name] ?? 0);
        }
      }
    });
  }

  Future<void> _addCategory() async {
    final name = _categoryName.text.trim();
    if (name.isEmpty || _savingCategory) return;
    setState(() => _savingCategory = true);
    try {
      await AppScope.of(context).settings.addCategory(name);
      if (!mounted) return;
      _categoryName.clear();
      if (!_categories.contains(name)) _categories = [..._categories, name];
      if (!_picked.contains(name)) _toggleCategory(name);
      setState(() => _addingCategory = false);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _formError = error.message);
    } finally {
      if (mounted) setState(() => _savingCategory = false);
    }
  }

  Future<void> _addPhotos(List<PickedPhoto> into) async {
    final source = await askPhotoSource(context);
    if (source == null || !mounted) return;
    try {
      final photos = await (widget.pickPhotos ?? pickPhotos)(source);
      if (!mounted || photos.isEmpty) return;
      setState(() => into.addAll(photos));
    } catch (error) {
      if (mounted) setState(() => _formError = error.toString());
    }
  }

  Future<void> _save() async {
    final supplier = _supplier;
    if (supplier == null) {
      setState(() => _formError = tr('Choose a customer.'));
      return;
    }
    if (_picked.isEmpty) {
      setState(() => _formError = tr('Choose at least one category.'));
      return;
    }
    final kg = _kgValue;
    final rate = _rateValue;
    final devices = _deviceList;
    if (kg < 0 || rate < 0 || devices.any((entry) => entry.$2.rateValue < 0)) {
      setState(() => _formError = tr('Weight and rate must be 0 or more.'));
      return;
    }
    for (final (name, device) in devices) {
      if (device.count < 1) {
        setState(() =>
            _formError = tr('Enter the quantity for {name}.', {'name': name}));
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final scope = AppScope.of(context);
      final code = await scope.shipments.create(IntakeDraft(
        supplierCode: supplier,
        categories: _picked.toList(),
        flightCode: _flight,
        flyerName: _flyer,
        bookedKg: kg,
        chargeRate: rate,
        chargeCurrency: _currency,
        description: _description.text.trim(),
        paymentTerms: _terms,
        pieces: [
          for (final (name, device) in devices) device.toPiece(name, _currency)
        ],
      ));
      // Photos go up after the shipment exists and keep going if the next
      // screen is left.
      final jobs = [
        for (final (name, device) in devices)
          for (final photo in device.photos)
            shipmentPhotoJob(scope.media, code, photo, deviceCategory: name),
        for (final photo in _parcelPhotos)
          shipmentPhotoJob(scope.media, code, photo),
      ];
      final uploads = jobs.isEmpty ? null : UploadQueue(jobs);
      if (uploads != null) unawaited(uploads.start());
      final flight = _selectedFlight;
      final booked = BookedShipment(
          code: code,
          customer: _selectedCustomer?.name ?? supplier,
          kg: kg,
          pieces: [for (final (name, device) in devices) (name, device.count)],
          terms: _terms,
          charge: _total,
          currency: _currency,
          flightCode: _flight,
          spaceLeftKg: flight == null ? null : flight.leftKg - kg);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => BookingDoneScreen(
              booking: booked,
              uploads: uploads,
              flightPreset: widget.lockedFlightCode)));
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _formError = error.message);
    } catch (error) {
      if (mounted) setState(() => _formError = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Nila Store · BG305 · 6 kg + 3 Mobile · Monthly".
  String _summary() {
    final customer = _selectedCustomer?.name ?? _supplier;
    final flight = _selectedFlight?.displayCode ??
        (_flight == null ? null : displayFlightCode(_flight!));
    return [
      customer ?? tr('No customer yet'),
      flight ?? (_flightDecided ? tr('Flight later') : tr('No flight yet')),
      bookingCargoText(_kgValue,
          [for (final (name, device) in _deviceList) (name, device.count)]),
      paymentTermsLabel(_terms),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final done = _done.where((value) => value).length;
    return WorkspaceScaffold(
        title: tr('New shipment'),
        subtitle: tr('One page · fill top to bottom'),
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                  child: StatusPill(
                      key: const Key('intake-progress'),
                      label: tr('{n} of 5 done', {'n': done}),
                      tone: ChipTone.green))),
        ],
        footer: FooterActions(
            error: _formError,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_summary(),
                      key: const Key('intake-summary'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, height: 1.4, color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                  AppButton(
                      key: const Key('intake-create'),
                      label: tr('Create shipment · {amount}',
                          {'amount': wholeMoney(_total, _currency)}),
                      icon: Icons.check_rounded,
                      kind: AppButtonKind.current,
                      busy: _busy,
                      onPressed: _loading ? null : _save),
                ])),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          _customerCard(),
          const SizedBox(height: 12),
          _flightCard(),
          const SizedBox(height: 12),
          _cargoCard(),
          const SizedBox(height: 12),
          _chargeCard(),
          const SizedBox(height: 12),
          _payCard(),
          const SizedBox(height: 12),
          _photosCard(),
        ]);
  }

  Widget _customerCard() {
    final customer = _selectedCustomer;
    final caption = Text(tr('1 · Customer'),
        style: const TextStyle(
            fontSize: 12, height: 1.35, color: AppColors.muted));
    if (customer == null) {
      return PaperCard(
          key: const Key('intake-customer'),
          onTap: _pickCustomer,
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          border: _mark(0) == StepMark.current
              ? const BorderSide(color: AppColors.accentLine, width: 1.5)
              : null,
          child: Row(children: [
            StepBadge(number: 1, mark: _mark(0)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  caption,
                  Text(tr('Choose a customer'),
                      style: const TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w700)),
                  Text(
                      _customers.isEmpty && !_loading
                          ? tr('Tap New to add a customer.')
                          : tr('Search by name, code or phone'),
                      style: const TextStyle(
                          fontSize: 12, height: 1.4, color: AppColors.muted)),
                ])),
            TextButton.icon(
                onPressed: _addCustomer,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(tr('New'))),
          ]));
    }
    return PaperCard(
        key: const Key('intake-customer'),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(children: [
          StepBadge(number: 1, mark: _mark(0)),
          const SizedBox(width: 12),
          LetterAvatar(customer.name,
              size: 40,
              color: AppColors.primarySoft,
              foreground: AppColors.primaryInk),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                caption,
                Text('${customer.name} · ${customer.code}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700)),
              ])),
          const SizedBox(width: 8),
          OutlinedButton(
              key: const Key('intake-customer-change'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.field),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontFamily: 'HindSiliguri',
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              onPressed: _pickCustomer,
              child: Text(tr('Change'))),
        ]));
  }

  String _flightLine(FlightSummary flight) {
    final left = flight.leftKg;
    final devices = [
      if (flight.mobiles > 0) trn(flight.mobiles, '{n} mobile', '{n} mobiles'),
      if (flight.laptops > 0) trn(flight.laptops, '{n} laptop', '{n} laptops'),
    ];
    return [
      left < 0
          ? tr('{kg} kg over', {'kg': plainKg(-left)})
          : tr('{kg} kg free', {'kg': plainKg(left)}),
      if (devices.isNotEmpty)
        tr('{devices} allowed', {'devices': devices.join(', ')}),
      flight.flyers.isEmpty
          ? tr('No flyer yet')
          : [for (final name in flight.flyers) name.trim().split(' ').first]
              .join(', '),
    ].join(' · ');
  }

  Widget _flightCard() {
    final kg = _kgValue;
    final selected = _selectedFlight;
    final locked = _flight != null && selected == null && !_loading;
    return StepCard(
        key: const Key('intake-flight'),
        number: 2,
        mark: _mark(1),
        title: tr('2 · Which flight?'),
        trailing: Text(tr('optional'),
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        gap: 10,
        children: [
          for (final flight in _flights)
            OptionRow(
                key: ValueKey('intake-flight-${flight.code}'),
                selected: flight.code == _flight,
                title: '${flight.displayCode} · ${shortDay(flight.date)}',
                subtitle: flight.code == _flight
                    ? '${_flightLine(flight)}\n${tr('{kg} kg left after this booking', {
                            'kg': plainKg(flight.leftKg - kg)
                          })}'
                    : _flightLine(flight),
                trailing: flight.code != _flight
                    ? null
                    : flight.leftKg - kg >= 0
                        ? StatusPill(label: tr('Fits'), tone: ChipTone.green)
                        : StatusPill(
                            label: tr('Over capacity'), tone: ChipTone.red),
                onTap: () => _chooseFlight(flight.code)),
          if (locked)
            OptionRow(
                selected: true,
                title: displayFlightCode(_flight!),
                subtitle: tr('Chosen on the flight page'),
                onTap: () {}),
          if (_flights.isEmpty && !locked && !_loading)
            Text(tr('No upcoming flight'),
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          DashedButton(
              key: const Key('intake-flight-later'),
              label: tr('Decide later'),
              selected: _flight == null && _flightDecided,
              onTap: () => _chooseFlight(null)),
          if (selected != null && selected.flyers.length > 1) ...[
            Text(
                tr('{flight} has {n} flyers. Who carries this cargo?', {
                  'flight': selected.displayCode,
                  'n': selected.flyers.length
                }),
                style: const TextStyle(
                    fontSize: 13, height: 1.45, color: AppColors.inkSoft)),
            _FlyerChoices(
                names: selected.flyers,
                selected: _flyer,
                onSelected: (name) => setState(() => _flyer = name)),
          ],
        ]);
  }

  Widget _cargoCard() {
    final devices = _deviceList;
    return StepCard(
        key: const Key('intake-cargo'),
        number: 3,
        mark: _mark(2),
        title: tr('3 · What is inside?'),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final name in _categories)
              CategoryChip(
                  label: name,
                  selected: _picked.contains(name),
                  onTap: () => _toggleCategory(name)),
            if (!_addingCategory)
              DashedButton(
                  key: const Key('intake-new-category'),
                  label: tr('New'),
                  icon: Icons.add_rounded,
                  radius: 999,
                  height: 44,
                  color: AppColors.primary,
                  onTap: () => setState(() => _addingCategory = true)),
          ]),
          if (_addingCategory)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                  controller: _categoryName,
                  autofocus: true,
                  decoration:
                      InputDecoration(hintText: tr('New category name'))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: AppButton(
                        label: tr('Add'),
                        kind: AppButtonKind.tonal,
                        busy: _savingCategory,
                        onPressed: _addCategory)),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: _savingCategory
                        ? null
                        : () => setState(() => _addingCategory = false),
                    child: Text(tr('Cancel'))),
              ]),
            ]),
          for (final (name, device) in devices) _deviceBlock(name, device),
          if (devices.isNotEmpty)
            Text(tr('Only the model is needed — no IMEI or serial.'),
                style: const TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.muted)),
        ]);
  }

  Widget _deviceBlock(String name, _DeviceDraft device) {
    final total = device.count;
    return Container(
        key: ValueKey('intake-device-$name'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            border: Border.all(color: AppColors.lineSoft),
            borderRadius: BorderRadius.circular(14)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(_pieceIcon(name), size: 18, color: AppColors.inkSoft),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    trn(total, '{name} · {n} piece', '{name} · {n} pieces',
                        {'name': name}),
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w700))),
          ]),
          for (var i = 0; i < device.models.length; i++) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(
                      key: ValueKey('$name-model-$i'),
                      controller: device.models[i].model,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                          isDense: true,
                          hintText: tr('Model, e.g. {example}', {
                            'example': _pieceIcon(name) == Icons.laptop_rounded
                                ? 'MacBook Air'
                                : 'iPhone 13'
                          }),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12)))),
              const SizedBox(width: 8),
              MiniStepper(
                  value: device.models[i].count,
                  lessLabel: device.models[i].count == 1
                      ? tr('Remove this model')
                      : null,
                  onLess: device.models[i].count > 1
                      ? () => setState(() => device.models[i].count--)
                      : device.models.length > 1
                          ? () => setState(
                              () => device.models.removeAt(i).model.dispose())
                          : null,
                  onMore: total < _maxPieces
                      ? () => setState(() => device.models[i].count++)
                      : null),
            ]),
          ],
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                  key: ValueKey('$name-add-model'),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4)),
                  onPressed: total < _maxPieces
                      ? () => setState(() => device.models.add(_ModelRow()))
                      : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(tr('Add another model')))),
          Row(children: [
            Expanded(
                child: Text(tr('Price per piece'),
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            SizedBox(
                width: 120,
                child: TextField(
                    key: ValueKey('$name-rate'),
                    controller: device.rate,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                        isDense: true,
                        hintText: '0',
                        prefixIcon: fieldSign(_sign, size: 15),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 0, minHeight: 0),
                        contentPadding:
                            const EdgeInsets.fromLTRB(0, 12, 10, 12)))),
          ]),
          const SizedBox(height: 12),
          Text.rich(
              TextSpan(children: [
                TextSpan(text: tr('{name} photos', {'name': name})),
                TextSpan(
                    text: ' · ${device.photos.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w400, color: AppColors.muted)),
              ]),
              style: const TextStyle(
                  fontSize: 13, height: 1.35, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          PhotoGrid(
              key: ValueKey('$name-photos'),
              photos: device.photos,
              addLabel: tr('Add {name} photos', {'name': name}),
              onAdd: () => _addPhotos(device.photos),
              onRemove: (i) => setState(() => device.photos.removeAt(i))),
        ]));
  }

  Widget _chargeCard() {
    final kg = _kgValue;
    final devices = _deviceList;
    final pieces = [
      for (final (name, device) in devices)
        '${device.count} $name × ${wholeMoney(device.rateValue, _currency)}'
    ];
    return StepCard(
        key: const Key('intake-charge-card'),
        number: 4,
        mark: _mark(3),
        title: tr('4 · Weight and charge'),
        trailing: PillToggle(
            options: const ['BDT', 'CNY'],
            selected: _currency,
            onChanged: (value) => setState(() => _currency = value)),
        children: [
          PairRow(
              first: LabeledField(
                  label: tr('Booked kg'),
                  child: TextField(
                      key: const Key('intake-kg'),
                      controller: _kg,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                      ],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                          hintText: '0',
                          suffixText: 'kg',
                          helperText: devices.isEmpty
                              ? null
                              : tr('0 for devices only')))),
              second: LabeledField(
                  label: tr('Rate per kg'),
                  child: TextField(
                      key: const Key('intake-rate'),
                      controller: _rate,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                      ],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                          hintText: '0',
                          prefixIcon: fieldSign(_sign),
                          prefixIconConstraints: const BoxConstraints(
                              minWidth: 0, minHeight: 0))))),
          Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(
                    child: Text(
                        [
                          '${plainKg(kg)} kg × ${wholeMoney(_rateValue, _currency)}',
                          if (pieces.isNotEmpty) '+ ${pieces.join(' + ')}',
                        ].join('\n'),
                        style: const TextStyle(
                            fontSize: 12, height: 1.5, color: heroSoft))),
                const SizedBox(width: 10),
                Flexible(
                    child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text(wholeMoney(_total, _currency),
                                key: const Key('intake-charge'),
                                maxLines: 1,
                                style: const TextStyle(
                                    fontSize: 24,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ]))))),
              ])),
        ]);
  }

  Widget _payCard() {
    final customer = _selectedCustomer;
    final usual = _usualTerms(customer);
    final name = customer?.name ?? '';
    final String note = customer == null
        ? tr('A change here applies to this booking only.')
        : _terms == usual
            ? usual == 'monthly'
                ? tr('{name} usually pays monthly.', {'name': name})
                : tr('{name} usually pays after delivery.', {'name': name})
            : usual == 'monthly'
                ? tr(
                    '{name} usually pays monthly. This booking will be collected after delivery instead.',
                    {
                        'name': name
                      })
                : tr(
                    '{name} usually pays after delivery. This booking goes on the monthly bill instead.',
                    {'name': name});
    return StepCard(
        key: const Key('intake-pay'),
        number: 5,
        mark: _mark(4),
        title: tr('How will they pay?'),
        gap: 10,
        children: [
          TileRow(gap: 8, children: [
            ChoiceTile(
                key: const Key('intake-terms-after'),
                title: tr('After delivery'),
                tick: true,
                selected: _terms != 'monthly',
                onTap: () => setState(() {
                      _terms = 'invoice';
                      _termsChosen = true;
                    })),
            ChoiceTile(
                key: const Key('intake-terms-monthly'),
                title: tr('Monthly'),
                tick: true,
                selected: _terms == 'monthly',
                onTap: () => setState(() {
                      _terms = 'monthly';
                      _termsChosen = true;
                    })),
          ]),
          Text(note,
              style: const TextStyle(
                  fontSize: 12, height: 1.45, color: AppColors.muted)),
        ]);
  }

  Widget _photosCard() => PaperCard(
      key: const Key('intake-photos'),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: tr('Parcel photos')),
                    TextSpan(
                        text: ' · ${tr('optional')}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.muted)),
                  ]),
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Text(tr('as many as you like'),
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: AppColors.muted)),
        ]),
        const SizedBox(height: 10),
        PhotoGrid(
            key: const Key('intake-parcel-photos'),
            photos: _parcelPhotos,
            addLabel: tr('Add parcel photos'),
            background: const Color(0xFFF7F9FC),
            onAdd: () => _addPhotos(_parcelPhotos),
            onRemove: (i) => setState(() => _parcelPhotos.removeAt(i))),
        const SizedBox(height: 14),
        LabeledField(
            label: tr('Description (optional)'),
            optional: true,
            helper: tr('Shown on the bill and to the hub.'),
            child: TextField(
                key: const Key('intake-description'),
                controller: _description,
                textCapitalization: TextCapitalization.sentences)),
      ]));
}

/// 950 rather than 950.0; keeps decimals when there are any.
String _number(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();

IconData _pieceIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('laptop')) return Icons.laptop_rounded;
  if (lower.contains('mobile') || lower.contains('phone')) {
    return Icons.smartphone_rounded;
  }
  return Icons.devices_other_rounded;
}

class _FlyerChoices extends StatelessWidget {
  const _FlyerChoices(
      {required this.names, required this.selected, required this.onSelected});
  final List<String> names;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget choice(String name) {
      final on = name == selected;
      return Semantics(
          selected: on,
          inMutuallyExclusiveGroup: true,
          button: true,
          child: Material(
              color: AppColors.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: on ? AppColors.primary : AppColors.field,
                      width: on ? 2 : 1)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: () => onSelected(name),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(children: [
                            LetterAvatar(name,
                                size: 32,
                                color:
                                    on ? AppColors.primary : AppColors.lineSoft,
                                foreground:
                                    on ? Colors.white : AppColors.inkSoft),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 15,
                                        height: 1.3,
                                        fontWeight: on
                                            ? FontWeight.w700
                                            : FontWeight.w600))),
                          ]))))));
    }

    return Column(children: [
      for (var i = 0; i < names.length; i += 2)
        Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: choice(names[i])),
              const SizedBox(width: 10),
              Expanded(
                  child: i + 1 < names.length
                      ? choice(names[i + 1])
                      : const SizedBox.shrink()),
            ])),
    ]);
  }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet(
      {required this.title, required this.options, this.selected});
  final String title;
  final List<({String value, String title, String subtitle})> options;
  final String? selected;
  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  var _query = '';
  @override
  Widget build(BuildContext context) {
    final options = widget.options.where((item) =>
        '${item.title} ${item.subtitle}'.toLowerCase().contains(_query));
    return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(children: [
                    Expanded(
                        child: Text(widget.title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600))),
                    TextButton.icon(
                        key: const Key('picker-new-customer'),
                        onPressed: () => Navigator.pop(context, _newCustomer),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(tr('New customer'))),
                    IconButton(
                        tooltip: tr('Close'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded)),
                  ])),
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                      decoration: InputDecoration(
                          hintText: tr('Search'),
                          prefixIcon: const Icon(Icons.search_rounded)),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()))),
              Expanded(
                  child: options.isEmpty
                      ? EmptyNote(
                          title: tr('No results found'),
                          body: tr('Try another name or code.'))
                      : ListView(children: [
                          for (final item in options)
                            ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 4),
                                leading:
                                    LetterAvatar.customer(item.title, size: 40),
                                title: Text(item.title),
                                subtitle: Text(item.subtitle),
                                trailing: item.value == widget.selected
                                    ? const Icon(Icons.check_rounded,
                                        color: AppColors.primary)
                                    : null,
                                onTap: () =>
                                    Navigator.pop(context, item.value)),
                        ])),
            ])));
  }
}
