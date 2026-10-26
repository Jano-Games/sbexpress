import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/session_user.dart';
import '../../data/models/shipment.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../imei/imei_guide_screen.dart';
import '../shipments/shipment_process_screen.dart';

enum ShipmentPickTarget { photos, invoice, imei }

class ShipmentPickerScreen extends StatefulWidget {
  const ShipmentPickerScreen({super.key, required this.target});

  final ShipmentPickTarget target;

  @override
  State<ShipmentPickerScreen> createState() => _ShipmentPickerScreenState();
}

class _ShipmentPickerScreenState extends State<ShipmentPickerScreen> {
  final _query = TextEditingController();
  List<OperationalShipment> _rows = const [];
  String? _error;
  var _loading = true;
  var _hub = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = AppScope.of(context);
      final hub = scope.session.user?.role == UserRole.hub;
      final rows = hub
          ? await scope.shipments.listHub()
          : await scope.shipments.listAdmin();
      if (!mounted) return;
      setState(() {
        _hub = hub;
        _rows = rows;
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

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final visible = [
      for (final row in _rows)
        if (query.isEmpty ||
            row.code.toLowerCase().contains(query) ||
            row.description.toLowerCase().contains(query))
          row,
    ];
    final title = switch (widget.target) {
      ShipmentPickTarget.photos => tr('Photos'),
      ShipmentPickTarget.invoice => tr('Invoice & share'),
      ShipmentPickTarget.imei => tr('IMEI photos'),
    };
    return WorkspaceScaffold(
        title: title,
        root: false,
        onRefresh: _load,
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  _hub
                      ? tr('Open by customer code. Names are not shown here.')
                      : tr('Choose the shipment to open.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: tr('Code'))),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && visible.isEmpty)
            EmptyNote(
                title: tr('No shipments'), body: tr('The list is empty.')),
          for (final row in visible) ...[
            DirectoryTile(
              title: row.code,
              subtitle:
                  '${_hub ? row.supplierCode : (row is AdminShipment ? (row.supplierName ?? row.supplierCode) : row.supplierCode)} · ${row.description}',
              badge: banglaStatus(row.status, row.statusLabel),
              onTap: () => _open(row.code),
            ),
            const SizedBox(height: 8),
          ],
        ]);
  }

  void _open(String code) {
    final screen = switch (widget.target) {
      ShipmentPickTarget.imei => DeviceUnitsScreen(code: code, hub: _hub),
      ShipmentPickTarget.photos when _hub => ShipmentProcessScreen(code: code),
      ShipmentPickTarget.photos =>
        AdminShipmentScreen(code: code, initialTab: 2),
      ShipmentPickTarget.invoice =>
        AdminShipmentScreen(code: code, initialTab: 1),
    };
    // The shipment may have been deleted there.
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen))
        .then((_) {
      if (mounted) _load();
    });
  }
}
