import '../../l10n/l10n.dart';
import '../../l10n/places.dart';
import '../json_read.dart';
import 'hub_flight.dart';

/// One step worth knowing about, shown under the bell. The server sends
/// English [title] and [body] (push later uses them); the app writes its own
/// words from [event] and [params], so Bangla reads naturally.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.event,
    required this.title,
    required this.body,
    required this.params,
    required this.read,
    required this.createdAt,
    this.flightCode,
    this.shipmentCode,
    this.customerCode,
  });

  final String id;
  final String event;
  final String title;
  final String body;
  final Map<String, Object?> params;
  final bool read;
  final DateTime createdAt;
  final String? flightCode;
  final String? shipmentCode;
  final String? customerCode;

  factory AppNotification.fromJson(Map<String, Object?> json) =>
      AppNotification(
        id: requiredString(json, 'id'),
        event: requiredString(json, 'event'),
        title: optionalString(json, 'title') ?? '',
        body: optionalString(json, 'body') ?? '',
        params: optionalMap(json, 'params') ?? const {},
        read: json['read'] == true,
        createdAt:
            DateTime.tryParse(requiredString(json, 'createdAt'))?.toLocal() ??
                DateTime.now(),
        flightCode: optionalString(json, 'flightCode'),
        shipmentCode: optionalString(json, 'shipmentCode'),
        customerCode: optionalString(json, 'customerCode'),
      );

  AppNotification markedRead() => AppNotification(
        id: id,
        event: event,
        title: title,
        body: body,
        params: params,
        read: true,
        createdAt: createdAt,
        flightCode: flightCode,
        shipmentCode: shipmentCode,
        customerCode: customerCode,
      );

  String _p(String key) => '${params[key] ?? ''}';
  int _n(String key) => params[key] is num ? (params[key] as num).toInt() : 0;

  String _day(String key) {
    final day = FlightDay.parse(_p(key));
    return day == null ? _p(key) : day.shortLabel;
  }

  String _at(String key) {
    final time = _p(key);
    return RegExp(r'^\d{1,2}:\d{2}').hasMatch(time)
        ? tr(' at {time}', {'time': time.substring(0, 5)})
        : '';
  }

  String _orders(String key) => trn(_n(key), '{n} order', '{n} orders');

  /// What the notification says, in the app's language.
  String get text {
    final flight = _p('flight');
    switch (event) {
      case 'flight_new':
        final days = _n('days');
        final when = days <= 0
            ? tr('today')
            : days == 1
                ? tr('tomorrow')
                : tr('in {n} days', {'n': days});
        final parts = [
          if (_n('orders') > 0) _orders('orders'),
          if (_p('flyers').isNotEmpty)
            tr('flyer {names}', {'names': _p('flyers')}),
        ].join(', ');
        return tr('New flight {flight}. Lands in Dhaka {date}{at}, {when}.', {
              'flight': flight,
              'date': _day('date'),
              'at': _at('arrTime'),
              'when': when
            }) +
            (parts.isEmpty
                ? ''
                : ' ${parts[0].toUpperCase()}${parts.substring(1)}.');
      case 'flight_changed':
        return tr('{flight} now lands in Dhaka {date}{at}.',
            {'flight': flight, 'date': _day('date'), 'at': _at('arrTime')});
      case 'flight_tomorrow':
        return _n('days') == 0
            ? tr('{flight} lands today{at}. {orders}.', {
                'flight': flight,
                'at': _at('arrTime'),
                'orders': _orders('orders')
              })
            : tr('{flight} lands tomorrow{at}. {orders}.', {
                'flight': flight,
                'at': _at('arrTime'),
                'orders': _orders('orders')
              });
      case 'flight_departed':
        final left = _p('from').isEmpty
            ? tr('{flight} has left{at}.',
                {'flight': flight, 'at': _at('depTime')})
            : tr('{flight} left {from}{at}.', {
                'flight': flight,
                'from': banglaPlace(_p('from'), fallback: _p('from')),
                'at': _at('depTime')
              });
        final lands = _p('arrTime').isEmpty
            ? ''
            : ' ${tr('Lands in Dhaka{at}.', {'at': _at('arrTime')})}';
        final moved = _n('moved') == 0
            ? ''
            : ' ${trn(_n('moved'), '{n} order is In transit.', '{n} orders are In transit.')}';
        return '$left$lands$moved';
      case 'flight_soon':
        return tr('{flight} lands in about 1 hour{at}.',
            {'flight': flight, 'at': _at('arrTime')});
      case 'flight_landed':
        return tr('{flight} landed in Dhaka{at}. {orders} to receive.', {
          'flight': flight,
          'at': _at('arrTime'),
          'orders': _orders('orders')
        });
      case 'flight_cancelled':
        return tr(
            'The airline cancelled {flight} on {date}. Nothing was changed here.',
            {'flight': flight, 'date': _day('date')});
      case 'flight_date_passed':
        return tr(
            '{flight} was due on {date}. The airline has no update. Confirm what happened.',
            {'flight': flight, 'date': _day('date')});
      case 'orders_received':
        return tr('{by} received {orders} from {flight} at the Dhaka hub.',
            {'by': _p('by'), 'orders': _orders('count'), 'flight': flight});
      case 'sort_waiting':
        return tr(
            '{by} sorted {customer} from {flight}: {orders}, {kg} kg. Waiting for approval.',
            {
              'by': _p('by'),
              'customer': _p('customer'),
              'flight': flight,
              'orders': _orders('orders'),
              'kg': _p('kg'),
            });
      case 'sort_sent_back':
        return tr('{customer} from {flight} sent back by {by}: {note}', {
          'customer': _p('customer'),
          'flight': flight,
          'by': _p('by'),
          'note': _p('note')
        });
      case 'sort_approved':
        return _p('partner') == 'Hub pickup'
            ? tr(
                '{customer} from {flight} approved. {orders} ready for pickup at the hub.',
                {
                    'customer': _p('customer'),
                    'flight': flight,
                    'orders': _orders('orders')
                  })
            : tr(
                '{customer} from {flight} approved. {orders} In delivery with {partner}.',
                {
                    'customer': _p('customer'),
                    'flight': flight,
                    'orders': _orders('orders'),
                    'partner': _p('partner'),
                  });
      case 'delivered':
        return tr(
            '{by} confirmed {orders} of {customer} from {flight} delivered.', {
          'by': _p('by'),
          'orders': _orders('orders'),
          'customer': _p('customer'),
          'flight': flight,
        });
      case 'problem':
        return tr('{order} has a problem ({type}): {reason}', {
          'order': _p('order'),
          'type': tr(_p('type').replaceAll('_', ' ')),
          'reason': _p('reason'),
        });
    }
    return body;
  }
}

class NotificationList {
  const NotificationList({required this.notifications, required this.unread});

  final List<AppNotification> notifications;
  final int unread;

  factory NotificationList.fromJson(Map<String, Object?> json) =>
      NotificationList(
        notifications: [
          for (final row in requiredMapList(json, 'notifications'))
            AppNotification.fromJson(row)
        ],
        unread: optionalInt(json, 'unread') ?? 0,
      );
}
