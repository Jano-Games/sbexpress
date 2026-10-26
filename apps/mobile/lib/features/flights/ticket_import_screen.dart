import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flyer.dart';
import '../../data/models/ticket_import.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../flyers/flyer_form_screen.dart';

/// Reads an e-ticket PDF and lets the admin edit or drop each journey before
/// the flights are created. The PDF itself is not kept.
class TicketImportScreen extends StatefulWidget {
  const TicketImportScreen({super.key, this.pickPdf});

  /// Returns the chosen PDF's bytes, or null when cancelled. Tests replace it.
  final Future<List<int>?> Function()? pickPdf;

  @override
  State<TicketImportScreen> createState() => _TicketImportScreenState();
}

class _TicketImportScreenState extends State<TicketImportScreen> {
  TicketImport? _ticket;
  List<TicketFlightDraft> _drafts = [];
  List<FlyerSummary> _flyers = const [];
  String? _flyer;
  String? _error;
  var _reading = false;
  var _saving = false;
  var _created = 0;

  /// The flyer made from the passenger's name on this screen.
  String? _added;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFlyers();
    });
  }

  Future<void> _loadFlyers() async {
    try {
      final rows = await AppScope.of(context).flyers.list();
      if (mounted) setState(() => _flyers = rows);
    } catch (_) {
      // The picker still offers the flyers the ticket matched.
    }
  }

  /// Opens the new flyer form with the passenger's name, then picks the
  /// flyer it made for this ticket.
  Future<void> _addPassenger(TicketImport ticket) async {
    final name = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => FlyerFormScreen(
            initialFirstName: ticket.firstName,
            initialLastName: ticket.lastName,
            returnName: true)));
    if (name == null || !mounted) return;
    await _loadFlyers();
    if (!mounted) return;
    setState(() {
      _added = name;
      _flyer = name;
      _error = null;
    });
  }

  Future<List<int>?> _defaultPick() async {
    final picked = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: const ['pdf']);
    if (picked.isEmpty) return null;
    return picked.single.readAsBytes();
  }

  Future<void> _read() async {
    final bytes = await (widget.pickPdf ?? _defaultPick)();
    if (bytes == null || !mounted) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final ticket = await AppScope.of(context).flights.readTicket(bytes);
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _drafts = TicketFlightDraft.fromImport(ticket);
        _flyer = ticket.flyerMatches.isEmpty ? null : ticket.flyerMatches.first;
      });
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  List<TicketFlightDraft> get _pending => [
        for (final draft in _drafts)
          if (!draft.saved) draft
      ];

  Future<void> _saveAll() async {
    final flyer = _flyer;
    if (flyer == null) {
      setState(() => _error = tr('Choose the flyer on this ticket.'));
      return;
    }
    final problem = _pending.map((draft) => draft.problem).nonNulls.firstOrNull;
    if (problem != null) {
      setState(() => _error = tr(problem));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = AppScope.of(context).flights;
    for (final draft in _pending) {
      try {
        await repo.createFromTicket(draft, flyer);
        _created += 1;
        draft.saved = true;
      } on ApiException catch (error) {
        draft.error = error.message;
      } catch (error) {
        draft.error = error.toString();
      }
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (_pending.isEmpty) Navigator.of(context).pop(true);
  }

  Future<void> _editLeg(TicketFlightDraft draft, TicketLeg leg) async {
    final changed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _LegSheet(leg: leg));
    if (changed == true && mounted) {
      setState(() => draft.error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    final pending = _pending.length;
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        appBar: BackTitle(
            title: tr('Import from ticket'),
            onBack: () => Navigator.of(context).pop(_created > 0)),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(pageGutter, 16, pageGutter, 28),
            children: [
              if (ticket == null) ...[
                EmptyNote(
                    icon: Icons.picture_as_pdf_outlined,
                    title: tr('Choose an e-ticket PDF'),
                    body: tr(
                        'Each journey on the ticket becomes a flight you can edit or remove before saving. The file is not stored.')),
                const SizedBox(height: 16),
              ],
              if (_reading) const LinearProgressIndicator(),
              if (_error != null) ErrorNote(message: _error!),
              if (ticket == null)
                AppButton(
                    key: const Key('ticket-pick'),
                    label: tr('Choose ticket PDF'),
                    icon: Icons.upload_file_rounded,
                    busy: _reading,
                    onPressed: _read)
              else ...[
                _TicketFacts(ticket: ticket),
                const SizedBox(height: 14),
                _FlyerPicker(
                    flyers: _flyers,
                    matches: ticket.flyerMatches,
                    passenger: ticket.passenger,
                    added: _added,
                    value: _flyer,
                    onChanged: (name) => setState(() {
                          _flyer = name;
                          _error = null;
                        })),
                if (ticket.flyerMatches.isEmpty && _added == null) ...[
                  const SizedBox(height: 10),
                  AppButton(
                      key: const Key('ticket-add-flyer'),
                      label: _passengerName(ticket) == null
                          ? tr('Add the passenger as a flyer')
                          : tr('Add {name} as a flyer',
                              {'name': _passengerName(ticket)}),
                      icon: Icons.person_add_alt_1_rounded,
                      kind: AppButtonKind.current,
                      onPressed: _saving ? null : () => _addPassenger(ticket)),
                ],
                const SizedBox(height: 18),
                for (var i = 0; i < _drafts.length; i++) ...[
                  _DraftCard(
                      key: ValueKey(_drafts[i]),
                      index: i,
                      draft: _drafts[i],
                      enabled: !_saving,
                      onRemove: () => setState(() => _drafts.removeAt(i)),
                      onEditLeg: (leg) => _editLeg(_drafts[i], leg),
                      onRemoveLeg: (leg) =>
                          setState(() => _drafts[i].legs.remove(leg)),
                      onChanged: () => setState(() => _drafts[i].error = null)),
                  const SizedBox(height: 12),
                ],
                if (_drafts.length > 1)
                  HintNote(
                      text: tr(
                          'A return ticket is paid once: enter its cost on one flight and leave the other at zero. No money moves here.')),
                if (_drafts.isEmpty)
                  EmptyNote(
                      icon: Icons.delete_outline_rounded,
                      title: tr('All flights removed'),
                      body: tr(
                          'Go back and import the ticket again to start over.')),
              ],
            ]),
        bottomNavigationBar: ticket == null || pending == 0
            ? null
            : ActionFooter(
                child: AppButton(
                    key: const Key('ticket-save'),
                    label:
                        trn(pending, 'Create {n} flight', 'Create {n} flights'),
                    icon: Icons.check_rounded,
                    busy: _saving,
                    onPressed: _saveAll)),
      ),
    );
  }
}

/// "Md Rifat Shahriar", or null when the ticket has no readable name.
String? _passengerName(TicketImport ticket) {
  final name = [ticket.firstName, ticket.lastName]
      .whereType<String>()
      .where((part) => part.trim().isNotEmpty)
      .join(' ');
  return name.isEmpty ? null : name;
}

class _TicketFacts extends StatelessWidget {
  const _TicketFacts({required this.ticket});
  final TicketImport ticket;

  @override
  Widget build(BuildContext context) => PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ticket.passenger ?? tr('Passenger not found'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        KvRow(label: tr('Airline PNR'), value: ticket.pnr ?? '—'),
        KvRow(label: tr('Ticket number'), value: ticket.ticketNumber ?? '—'),
        KvRow(label: tr('Issued'), value: ticket.issuedOn ?? '—'),
        if (ticket.agency != null)
          KvRow(label: tr('Agency'), value: ticket.agency!),
      ]));
}

class _FlyerPicker extends StatelessWidget {
  const _FlyerPicker(
      {required this.flyers,
      required this.matches,
      required this.passenger,
      required this.added,
      required this.value,
      required this.onChanged});
  final List<FlyerSummary> flyers;
  final List<String> matches;
  final String? passenger;

  /// A flyer just made from the ticket; listed even before the list has it.
  final String? added;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final names = {
      ...matches,
      if (added != null) added!,
      for (final flyer in flyers)
        if (flyer.archivedAt == null) flyer.name
    }.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(title: tr('Flyer')),
      DropdownButtonFormField<String>(
          // A new key when the value changes from outside, e.g. a new flyer.
          key: ValueKey('ticket-flyer-$value'),
          initialValue: names.contains(value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: tr('Flyer on this ticket')),
          items: [
            for (final name in names)
              DropdownMenuItem(
                  value: name,
                  child: Text(
                      matches.contains(name)
                          ? '$name · ${tr('matches ticket')}'
                          : name,
                      overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged),
      if (matches.isEmpty && added == null) ...[
        const SizedBox(height: 10),
        HintNote(
            text: tr(
                'No flyer matches {passenger}. Choose one, or add the flyer first.',
                {'passenger': passenger ?? tr('this passenger')})),
      ],
    ]);
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard(
      {super.key,
      required this.index,
      required this.draft,
      required this.enabled,
      required this.onRemove,
      required this.onEditLeg,
      required this.onRemoveLeg,
      required this.onChanged});
  final int index;
  final TicketFlightDraft draft;
  final bool enabled;
  final VoidCallback onRemove, onChanged;
  final ValueChanged<TicketLeg> onEditLeg, onRemoveLeg;

  String get _direction => switch (draft.direction) {
        'to_bangladesh' => tr('To Bangladesh'),
        'from_bangladesh' => tr('From Bangladesh'),
        _ => tr('Other journey'),
      };

  @override
  Widget build(BuildContext context) {
    final active = enabled && !draft.saved;
    return PaperCard(
        border: draft.saved
            ? const BorderSide(color: AppColors.ok, width: 1.5)
            : null,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      tr('Flight {n} · {direction}',
                          {'n': index + 1, 'direction': _direction}),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                      '${draft.route} · ${draft.legs.isEmpty ? '—' : draft.legs.first.date}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                ])),
            if (draft.saved)
              StatusPill(label: tr('Saved'), tone: ChipTone.green)
            else
              IconButton(
                  key: Key('ticket-remove-$index'),
                  tooltip: tr('Remove flight'),
                  color: AppColors.danger,
                  onPressed: active ? onRemove : null,
                  icon: const Icon(Icons.delete_outline_rounded)),
          ]),
          const SizedBox(height: 8),
          for (final leg in draft.legs)
            _LegRow(
                leg: leg,
                canRemove: active && draft.legs.length > 1,
                onEdit: active ? () => onEditLeg(leg) : null,
                onRemove: () => onRemoveLeg(leg)),
          const Divider(height: 24),
          Row(children: [
            Expanded(
                child: _NumberField(
                    label: tr('Cargo kg'),
                    value: '${draft.spaceKg}',
                    enabled: active,
                    onChanged: (v) {
                      draft.spaceKg = int.tryParse(v) ?? 0;
                      onChanged();
                    })),
            const SizedBox(width: 8),
            Expanded(
                child: _NumberField(
                    label: tr('Mobiles'),
                    value: '${draft.mobiles}',
                    enabled: active,
                    onChanged: (v) {
                      draft.mobiles = int.tryParse(v) ?? 0;
                      onChanged();
                    })),
            const SizedBox(width: 8),
            Expanded(
                child: _NumberField(
                    label: tr('Laptops'),
                    value: '${draft.laptops}',
                    enabled: active,
                    onChanged: (v) {
                      draft.laptops = int.tryParse(v) ?? 0;
                      onChanged();
                    })),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _NumberField(
                    label: tr('Ticket cost (BDT)'),
                    value: draft.actualCost == 0 ? '' : '${draft.actualCost}',
                    decimal: true,
                    enabled: active,
                    onChanged: (v) {
                      draft.actualCost = double.tryParse(v) ?? 0;
                      onChanged();
                    })),
            const SizedBox(width: 8),
            Expanded(
                child: _NumberField(
                    label: tr('Our share (BDT)'),
                    value: draft.agencyShare == 0 ? '' : '${draft.agencyShare}',
                    decimal: true,
                    enabled: active,
                    onChanged: (v) {
                      draft.agencyShare = double.tryParse(v) ?? 0;
                      onChanged();
                    })),
          ]),
          if (draft.error != null) ...[
            const SizedBox(height: 10),
            ErrorNote(message: draft.error!),
          ],
        ]));
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow(
      {required this.leg,
      required this.canRemove,
      required this.onEdit,
      required this.onRemove});
  final TicketLeg leg;
  final bool canRemove;
  final VoidCallback? onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            const IconBadge(Icons.flight_rounded, size: 36),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${leg.code} · ${leg.date}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(
                      '${leg.fromIata.isEmpty ? leg.fromCity : leg.fromIata} ${leg.depTime} → ${leg.toIata.isEmpty ? leg.toCity : leg.toIata} ${leg.arrTime}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                ])),
            if (onEdit != null)
              IconButton(
                  tooltip: tr('Edit segment'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20)),
            if (canRemove)
              IconButton(
                  tooltip: tr('Remove segment'),
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 20)),
          ])));
}

class _NumberField extends StatelessWidget {
  const _NumberField(
      {required this.label,
      required this.value,
      required this.enabled,
      required this.onChanged,
      this.decimal = false});
  final String label, value;
  final bool enabled, decimal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
      initialValue: value,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: onChanged);
}

/// Edits one segment in place; pops true when saved.
class _LegSheet extends StatefulWidget {
  const _LegSheet({required this.leg});
  final TicketLeg leg;

  @override
  State<_LegSheet> createState() => _LegSheetState();
}

class _LegSheetState extends State<_LegSheet> {
  late final _fields = <String, TextEditingController>{
    'code': TextEditingController(text: widget.leg.code),
    'date': TextEditingController(text: widget.leg.date),
    'fromIata': TextEditingController(text: widget.leg.fromIata),
    'fromCity': TextEditingController(text: widget.leg.fromCity),
    'toIata': TextEditingController(text: widget.leg.toIata),
    'toCity': TextEditingController(text: widget.leg.toCity),
    'depTime': TextEditingController(text: widget.leg.depTime),
    'arrTime': TextEditingController(text: widget.leg.arrTime),
  };

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    String value(String key, {bool upper = false}) {
      final text = _fields[key]!.text.trim();
      return upper ? text.toUpperCase() : text;
    }

    widget.leg
      ..code = value('code', upper: true).replaceAll(RegExp(r'[\s-]'), '')
      ..date = value('date')
      ..fromIata = value('fromIata', upper: true)
      ..fromCity = value('fromCity')
      ..toIata = value('toIata', upper: true)
      ..toCity = value('toCity')
      ..depTime = value('depTime')
      ..arrTime = value('arrTime');
    Navigator.of(context).pop(true);
  }

  Widget _field(String key, String label, {String? hint}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
          controller: _fields[key],
          decoration: InputDecoration(labelText: label, hintText: hint)));

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(pageGutter, 0, pageGutter,
          MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('Edit segment'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        _field('code', tr('Flight number'), hint: 'MU2035'),
        _field('date', tr('Departure date'), hint: 'YYYY-MM-DD'),
        Row(children: [
          Expanded(child: _field('fromIata', tr('From code'), hint: 'KMG')),
          const SizedBox(width: 8),
          Expanded(child: _field('toIata', tr('To code'), hint: 'DAC')),
        ]),
        Row(children: [
          Expanded(child: _field('fromCity', tr('From city'))),
          const SizedBox(width: 8),
          Expanded(child: _field('toCity', tr('To city'))),
        ]),
        Row(children: [
          Expanded(child: _field('depTime', tr('Departs'), hint: '12:10')),
          const SizedBox(width: 8),
          Expanded(child: _field('arrTime', tr('Arrives'), hint: '13:00')),
        ]),
        const SizedBox(height: 6),
        AppButton(
            key: const Key('ticket-leg-save'),
            label: tr('Save segment'),
            onPressed: _save),
      ])));
}
