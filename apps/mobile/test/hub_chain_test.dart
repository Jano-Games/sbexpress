import 'package:flutter_test/flutter_test.dart';
import 'package:sbexpress/data/hub/hub_chain.dart';
import 'package:sbexpress/data/models/shipment.dart';

LastMileBooking booking(String mode) => const LastMileBooking(
      courier: 'Pathao',
      ref: 'BD-1',
      mode: 'courier',
      bookedAt: null,
      dispatchedAt: null,
      handedOverAt: null,
    ).let(mode);

extension on LastMileBooking {
  LastMileBooking let(String mode) => LastMileBooking(
        courier: mode == 'pickup' ? 'Hub pickup' : courier,
        ref: ref,
        mode: mode,
        bookedAt: bookedAt,
        dispatchedAt: dispatchedAt,
        handedOverAt: handedOverAt,
      );
}

void main() {
  test('chain order stays weigh → pack → courier → dispatch → handover', () {
    expect(HubChainStep.values.map((step) => step.name).join(' → '), hubChainOrderLabel);
    expect(hubChainOrderLabel, 'weigh → pack → courier → dispatch → handover');
  });

  test('each shipment exposes exactly one current step, in chain order', () {
    final weigh = resolveHubChain(status: 'received_bd_hub', weighedKg: null, packedAt: null, lastMile: null, exception: null);
    expect(weigh.current, HubChainStep.weigh);
    expect(weigh.visual(HubChainStep.pack), HubStepVisual.waiting);

    final pack = resolveHubChain(status: 'received_bd_hub', weighedKg: 2, packedAt: null, lastMile: null, exception: null);
    expect(pack.current, HubChainStep.pack);
    expect(pack.visual(HubChainStep.weigh), HubStepVisual.done);

    final courier = resolveHubChain(
      status: 'ready_for_last_mile',
      weighedKg: 2,
      packedAt: '2026-10-18T00:00:00.000Z',
      lastMile: null,
      exception: null,
    );
    expect(courier.current, HubChainStep.courier);
    expect(courier.visual(HubChainStep.dispatch), HubStepVisual.waiting);

    final dispatch = resolveHubChain(
      status: 'ready_for_last_mile',
      weighedKg: 2,
      packedAt: '2026-10-18T00:00:00.000Z',
      lastMile: booking('courier'),
      exception: null,
    );
    expect(dispatch.current, HubChainStep.dispatch);
    expect(dispatch.visual(HubChainStep.courier), HubStepVisual.done);
    expect(dispatch.visual(HubChainStep.handover), HubStepVisual.waiting);

    final handover = resolveHubChain(
      status: 'out_for_delivery',
      weighedKg: 2,
      packedAt: '2026-10-18T00:00:00.000Z',
      lastMile: booking('courier'),
      exception: null,
    );
    expect(handover.current, HubChainStep.handover);
    expect(handover.visual(HubChainStep.dispatch), HubStepVisual.done);
  });

  test('pickup skips dispatch without removing it from the chain', () {
    final snapshot = resolveHubChain(
      status: 'ready_for_last_mile',
      weighedKg: 1,
      packedAt: '2026-10-18T00:00:00.000Z',
      lastMile: booking('pickup'),
      exception: null,
    );
    expect(snapshot.current, HubChainStep.handover);
    expect(snapshot.visual(HubChainStep.dispatch), HubStepVisual.skipped);
    expect(HubChainStep.values, hasLength(5));
  });

  test('receive is outside the five-step chain', () {
    final customs = resolveHubChain(status: 'customs_cleared', weighedKg: null, packedAt: null, lastMile: null, exception: null);
    expect(customs.needsReceive, isTrue);
    expect(customs.current, isNull);
    expect(customs.visual(HubChainStep.weigh), HubStepVisual.waiting);

    final transit = resolveHubChain(status: 'in_transit', weighedKg: null, packedAt: null, lastMile: null, exception: null);
    expect(transit.waitingOnCustoms, isTrue);
    expect(transit.needsReceive, isFalse);
  });

  test('an exception blocks the current action and a closed exception stays blocked', () {
    final held = resolveHubChain(status: 'received_bd_hub', weighedKg: null, packedAt: null, lastMile: null, exception: 'on_hold');
    expect(held.blockedByException, isTrue);
    expect(held.current, isNull);

    final lost = resolveHubChain(status: 'received_bd_hub', weighedKg: 1, packedAt: null, lastMile: null, exception: 'lost');
    expect(lost.blockedByException, isTrue);
    expect(lost.current, isNull);
  });

  test('list rows do not relabel the delivery tail as only courier', () {
    final row = OperationalShipment.fromJson({
      'code': 'SH-2',
      'supplierCode': 'C-2',
      'flightCode': null,
      'flightDate': null,
      'bookedKg': 1,
      'weighedKg': 1,
      'effectiveKg': 1,
      'weightDelta': null,
      'description': 'box',
      'categories': ['general'],
      'status': 'ready_for_last_mile',
      'statusIndex': 6,
      'statusLabel': 'Ready for Last Mile',
      'exception': null,
      'exceptionReason': '',
      'date': '2026-10-18',
    });
    expect(hubListStep(row), HubListStep.deliveryChain);
    expect(hubListStepLabel(HubListStep.deliveryChain), 'courier → dispatch → handover');
    final counts = HubWorkCounts.fromShipments([row]);
    expect(counts.deliveryChain, 1);
    expect(counts.weigh, 0);
    expect(counts.pack, 0);
    expect(counts.earliest, HubListStep.deliveryChain);
  });

  test('today counts keep weigh ahead of pack ahead of the delivery chain', () {
    OperationalShipment row(String code, String status, double? weighedKg) {
      return OperationalShipment.fromJson({
        'code': code,
        'supplierCode': 'C-1',
        'flightCode': null,
        'flightDate': null,
        'bookedKg': 1,
        'weighedKg': weighedKg,
        'effectiveKg': weighedKg ?? 1,
        'weightDelta': null,
        'description': 'box',
        'categories': ['general'],
        'status': status,
        'statusIndex': 5,
        'statusLabel': status,
        'exception': null,
        'exceptionReason': '',
        'date': '2026-10-18',
      });
    }

    final counts = HubWorkCounts.fromShipments([
      row('SH-W', 'received_bd_hub', null),
      row('SH-P', 'received_bd_hub', 2),
      row('SH-D', 'out_for_delivery', 2),
    ]);
    expect(counts.remaining, 3);
    expect(counts.earliest, HubListStep.weigh);
    expect(hubChainOrderLabel, 'weigh → pack → courier → dispatch → handover');
  });
}
