import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/uploads/upload_queue.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart' show LinkBox, heroSoft;
import '../../widgets/quick_parts.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import 'intake_screen.dart';

/// What was booked, for the confirmation.
class BookedShipment {
  const BookedShipment({
    required this.code,
    required this.customer,
    required this.kg,
    required this.pieces,
    required this.terms,
    required this.charge,
    required this.currency,
    this.flightCode,
    this.spaceLeftKg,
  });

  final String code;
  final String customer;
  final double kg;

  /// Device category and how many pieces of it.
  final List<(String, int)> pieces;

  /// `invoice` (after delivery) or `monthly`.
  final String terms;
  final double charge;
  final String currency;
  final String? flightCode;

  /// Room left on the flight after this booking.
  final double? spaceLeftKg;
}

/// "6 kg + 3 Mobile + 1 Laptop".
String bookingCargoText(double kg, List<(String, int)> pieces) => [
      if (kg > 0 || pieces.isEmpty) '${plainKg(kg)} kg',
      for (final (name, count) in pieces) '$count $name',
    ].join(' + ');

/// Shown once a booking is created: what was booked, its charge, the photo
/// uploads (which keep going if the screen closes) and what to do next.
class BookingDoneScreen extends StatefulWidget {
  const BookingDoneScreen(
      {super.key, required this.booking, this.uploads, this.flightPreset});

  final BookedShipment booking;
  final UploadQueue? uploads;

  /// The flight a new booking starts on, when this one came from a flight.
  final String? flightPreset;

  @override
  State<BookingDoneScreen> createState() => _BookingDoneScreenState();
}

class _BookingDoneScreenState extends State<BookingDoneScreen> {
  String? _link;
  String? _error;
  var _sharing = false;

  Future<void> _share() async {
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      final link = await AppScope.of(context)
          .shipments
          .shareTracking(widget.booking.code);
      if (!mounted) return;
      setState(() => _link = link.url);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _open() => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AdminShipmentScreen(code: widget.booking.code)));

  void _again() =>
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => IntakeScreen(lockedFlightCode: widget.flightPreset)));

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final flight = booking.flightCode == null
        ? null
        : displayFlightCode(booking.flightCode!);
    final cargo = bookingCargoText(booking.kg, booking.pieces);
    final summary = [
      booking.customer,
      flight == null
          ? cargo
          : tr('{cargo} on {flight}', {'cargo': cargo, 'flight': flight}),
      booking.terms == 'monthly'
          ? tr('pays monthly')
          : tr('pays after delivery'),
    ].join(' · ');
    final uploads = widget.uploads;
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                            pageGutter, 40, pageGutter, 28),
                        children: [
                          Center(
                              child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                      color: AppColors.okSoft,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.check_rounded,
                                      size: 38, color: AppColors.ok))),
                          const SizedBox(height: 12),
                          Text(tr('{code} is booked', {'code': booking.code}),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 22,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 320),
                                  child: Text(summary,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.45,
                                          color: AppColors.muted)))),
                          const SizedBox(height: 20),
                          _ChargeCard(
                              charge:
                                  wholeMoney(booking.charge, booking.currency),
                              flight: flight,
                              spaceLeftKg: booking.spaceLeftKg),
                          if (uploads != null) ...[
                            const SizedBox(height: 16),
                            UploadProgressCard(
                                key: const Key('booking-uploads'),
                                queue: uploads,
                                note: tr(
                                    'You can leave this screen — the rest keeps uploading.')),
                          ],
                          const SizedBox(height: 16),
                          SurfaceGroup(children: [
                            MenuRow(
                                key: const Key('booking-open'),
                                icon: Icons.inventory_2_outlined,
                                title:
                                    tr('Open {code}', {'code': booking.code}),
                                subtitle: tr('Costs, bill and tracking'),
                                onTap: _open),
                            MenuRow(
                                key: const Key('booking-share'),
                                icon: Icons.link_rounded,
                                tone: ChipTone.neutral,
                                title: tr('Share tracking link'),
                                subtitle: tr('Send it to {name}',
                                    {'name': booking.customer}),
                                trailing: _sharing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : null,
                                onTap: _sharing ? () {} : _share),
                          ]),
                          if (_link != null) ...[
                            const SizedBox(height: 12),
                            LinkBox(url: _link!),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            ErrorNote(message: _error!),
                          ],
                        ])))),
        bottomNavigationBar: ActionFooter(
            child: Row(children: [
          Expanded(
              child: OutlinedButton(
                  key: const Key('booking-done'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 52),
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.field),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(tr('Done'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)))),
          const SizedBox(width: 10),
          Expanded(
              child: AppButton(
                  key: const Key('booking-again'),
                  label: tr('Book another'),
                  icon: Icons.add_rounded,
                  kind: AppButtonKind.current,
                  onPressed: _again)),
        ])));
  }
}

/// Navy card with the charge and the flight's room left.
class _ChargeCard extends StatelessWidget {
  const _ChargeCard(
      {required this.charge, required this.flight, required this.spaceLeftKg});
  final String charge;
  final String? flight;
  final double? spaceLeftKg;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(heroRadius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
              child: Text(tr('Charge'),
                  style: const TextStyle(
                      fontSize: 13, height: 1.4, color: heroSoft))),
          const SizedBox(width: 8),
          Flexible(
              child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(charge,
                          key: const Key('booking-charge'),
                          maxLines: 1,
                          style: const TextStyle(
                              fontSize: 26,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()]))))),
        ]),
        const SizedBox(height: 4),
        Text(tr('The bill is made from this charge by itself.'),
            key: const Key('booking-bill-auto'),
            style: const TextStyle(fontSize: 12, height: 1.4, color: heroSoft)),
        if (flight != null && spaceLeftKg != null) ...[
          const SizedBox(height: 10),
          Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x24FFFFFF)))),
              child: Row(children: [
                Expanded(
                    child: Text(tr('{flight} space left', {'flight': flight}),
                        style: const TextStyle(
                            fontSize: 13, height: 1.4, color: heroSoft))),
                const SizedBox(width: 8),
                Text(
                    spaceLeftKg! < 0
                        ? tr('{kg} kg over', {'kg': plainKg(-spaceLeftKg!)})
                        : '${plainKg(spaceLeftKg!)} kg',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: spaceLeftKg! < 0
                            ? const Color(0xFFFFB3B0)
                            : Colors.white)),
              ])),
        ],
      ]));
}
