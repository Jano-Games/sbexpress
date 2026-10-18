import '../models/shipment.dart';

/// Dhaka hub handling order. Do not reorder, rename, or drop a step.
const String hubChainOrderLabel = 'weigh → pack → courier → dispatch → handover';

enum HubChainStep { weigh, pack, courier, dispatch, handover }

enum HubStepVisual { waiting, current, done, skipped }

/// How far a list row can see without the detail payload.
///
/// List rows have weight and status, not the courier reference, so the
/// delivery tail stays one bucket instead of being mislabeled as courier.
enum HubListStep { weigh, pack, deliveryChain, none }

const Set<String> closedHubExceptions = {'cancelled', 'lost', 'returned'};

class HubChainSnapshot {
  const HubChainSnapshot({
    required this.weigh,
    required this.pack,
    required this.courier,
    required this.dispatch,
    required this.handover,
    required this.current,
    required this.needsReceive,
    required this.waitingOnCustoms,
    required this.notAtHub,
    required this.blockedByException,
    required this.delivered,
  });

  final HubStepVisual weigh;
  final HubStepVisual pack;
  final HubStepVisual courier;
  final HubStepVisual dispatch;
  final HubStepVisual handover;
  final HubChainStep? current;
  final bool needsReceive;
  final bool waitingOnCustoms;
  final bool notAtHub;
  final bool blockedByException;
  final bool delivered;

  HubStepVisual visual(HubChainStep step) {
    switch (step) {
      case HubChainStep.weigh:
        return weigh;
      case HubChainStep.pack:
        return pack;
      case HubChainStep.courier:
        return courier;
      case HubChainStep.dispatch:
        return dispatch;
      case HubChainStep.handover:
        return handover;
    }
  }

  String title(HubChainStep step) {
    switch (step) {
      case HubChainStep.weigh:
        return 'ওজন';
      case HubChainStep.pack:
        return 'প্যাক';
      case HubChainStep.courier:
        return 'কুরিয়ার';
      case HubChainStep.dispatch:
        return 'ডিসপ্যাচ';
      case HubChainStep.handover:
        return 'হ্যান্ডওভার';
    }
  }
}

HubListStep hubListStep(OperationalShipment row) {
  if (row.exception != null && closedHubExceptions.contains(row.exception)) {
    return HubListStep.none;
  }
  if (row.status == 'received_bd_hub' && row.weighedKg == null) return HubListStep.weigh;
  if (row.status == 'received_bd_hub') return HubListStep.pack;
  if (row.status == 'ready_for_last_mile' || row.status == 'out_for_delivery') {
    return HubListStep.deliveryChain;
  }
  return HubListStep.none;
}

String hubListStepLabel(HubListStep step) {
  switch (step) {
    case HubListStep.weigh:
      return 'ওজন';
    case HubListStep.pack:
      return 'প্যাক';
    case HubListStep.deliveryChain:
      return 'courier → dispatch → handover';
    case HubListStep.none:
      return 'এখন হাবের ধাপ নেই';
  }
}

class HubWorkCounts {
  const HubWorkCounts({required this.weigh, required this.pack, required this.deliveryChain});

  final int weigh;
  final int pack;
  final int deliveryChain;

  factory HubWorkCounts.fromShipments(List<OperationalShipment> rows) {
    var weigh = 0;
    var pack = 0;
    var deliveryChain = 0;
    for (final row in rows) {
      switch (hubListStep(row)) {
        case HubListStep.weigh:
          weigh += 1;
        case HubListStep.pack:
          pack += 1;
        case HubListStep.deliveryChain:
          deliveryChain += 1;
        case HubListStep.none:
          break;
      }
    }
    return HubWorkCounts(weigh: weigh, pack: pack, deliveryChain: deliveryChain);
  }
}

const Set<String> _beforeDhakaHub = {
  'pending',
  'received_cn_hub',
  'ready_for_shipment',
  'in_transit',
  'customs_cleared',
};

HubChainSnapshot resolveHubChain({
  required String status,
  required double? weighedKg,
  required String? packedAt,
  required LastMileBooking? lastMile,
  required String? exception,
}) {
  final blocked = exception != null && exception.isNotEmpty;
  final closed = exception != null && closedHubExceptions.contains(exception);

  if (closed) {
    return const HubChainSnapshot(
      weigh: HubStepVisual.waiting,
      pack: HubStepVisual.waiting,
      courier: HubStepVisual.waiting,
      dispatch: HubStepVisual.waiting,
      handover: HubStepVisual.waiting,
      current: null,
      needsReceive: false,
      waitingOnCustoms: false,
      notAtHub: false,
      blockedByException: true,
      delivered: false,
    );
  }

  if (status == 'delivered') {
    final pickup = lastMile?.isPickup ?? false;
    return HubChainSnapshot(
      weigh: HubStepVisual.done,
      pack: HubStepVisual.done,
      courier: HubStepVisual.done,
      dispatch: pickup ? HubStepVisual.skipped : HubStepVisual.done,
      handover: HubStepVisual.done,
      current: null,
      needsReceive: false,
      waitingOnCustoms: false,
      notAtHub: false,
      blockedByException: false,
      delivered: true,
    );
  }

  if (_beforeDhakaHub.contains(status)) {
    return HubChainSnapshot(
      weigh: HubStepVisual.waiting,
      pack: HubStepVisual.waiting,
      courier: HubStepVisual.waiting,
      dispatch: HubStepVisual.waiting,
      handover: HubStepVisual.waiting,
      current: null,
      needsReceive: status == 'customs_cleared' && !blocked,
      waitingOnCustoms: status == 'in_transit',
      notAtHub: status != 'customs_cleared' && status != 'in_transit',
      blockedByException: blocked,
      delivered: false,
    );
  }

  final weighed = weighedKg != null;
  final packed = packedAt != null && packedAt.isNotEmpty;
  final booked = lastMile != null && lastMile.ref.trim().isNotEmpty;
  final pickup = booked && lastMile.isPickup;

  var weigh = HubStepVisual.waiting;
  var pack = HubStepVisual.waiting;
  var courier = HubStepVisual.waiting;
  var dispatch = HubStepVisual.waiting;
  var handover = HubStepVisual.waiting;
  HubChainStep? current;

  if (!weighed) {
    weigh = blocked ? HubStepVisual.waiting : HubStepVisual.current;
    current = blocked ? null : HubChainStep.weigh;
  } else {
    weigh = HubStepVisual.done;
    if (!packed) {
      pack = blocked ? HubStepVisual.waiting : HubStepVisual.current;
      current = blocked ? null : HubChainStep.pack;
    } else {
      pack = HubStepVisual.done;
      if (!booked) {
        courier = blocked ? HubStepVisual.waiting : HubStepVisual.current;
        current = blocked ? null : HubChainStep.courier;
      } else {
        courier = HubStepVisual.done;
        if (pickup) {
          dispatch = HubStepVisual.skipped;
          handover = blocked ? HubStepVisual.waiting : HubStepVisual.current;
          current = blocked ? null : HubChainStep.handover;
        } else if (status == 'out_for_delivery') {
          dispatch = HubStepVisual.done;
          handover = blocked ? HubStepVisual.waiting : HubStepVisual.current;
          current = blocked ? null : HubChainStep.handover;
        } else {
          dispatch = blocked ? HubStepVisual.waiting : HubStepVisual.current;
          current = blocked ? null : HubChainStep.dispatch;
        }
      }
    }
  }

  return HubChainSnapshot(
    weigh: weigh,
    pack: pack,
    courier: courier,
    dispatch: dispatch,
    handover: handover,
    current: current,
    needsReceive: false,
    waitingOnCustoms: false,
    notAtHub: false,
    blockedByException: blocked,
    delivered: false,
  );
}

HubChainSnapshot chainForDetail(HubShipmentDetail detail) {
  return resolveHubChain(
    status: detail.status,
    weighedKg: detail.weighedKg,
    packedAt: detail.packedAt,
    lastMile: detail.lastMile,
    exception: detail.exception,
  );
}
