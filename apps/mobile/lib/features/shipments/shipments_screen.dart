import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/hub/hub_chain.dart';
import '../../data/models/session_user.dart';
import '../../data/models/shipment.dart';
import '../../data/repositories/shipment_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';
import '../admin/admin_shipment_screen.dart';
import '../intake/intake_screen.dart';
import 'shipment_process_screen.dart';

class ShipmentsScreen extends StatefulWidget {
  const ShipmentsScreen({super.key, required this.role, required this.shipments});

  final UserRole role;
  final ShipmentRepository shipments;

  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final _query = TextEditingController();
  List<OperationalShipment> _hub = const [];
  List<AdminShipment> _admin = const [];
  String? _error;
  var _loading = true;
  var _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
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
      switch (widget.role) {
        case UserRole.hub:
          final rows = await widget.shipments.listHub();
          if (!mounted) return;
          setState(() => _hub = rows);
        case UserRole.admin:
          final rows = await widget.shipments.listAdmin();
          if (!mounted) return;
          setState(() => _admin = rows);
      }
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
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              PageHeader(
                title: 'Shipment',
                subtitle: widget.role == UserRole.hub ? 'কোড, ওজন ও পরের ধাপ। কাস্টমারের নাম বা টাকা নেই।' : 'অপারেশন ও বিল। নতুন ইনটেক এখান থেকে।',
              ),
              if (widget.role == UserRole.admin) ...[
                AppButton(
                  label: 'নতুন শিপমেন্ট',
                  kind: AppButtonKind.current,
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const IntakeScreen()));
                    await _load();
                  },
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'কোড বা কার্গো'),
              ),
              const SizedBox(height: 12),
              ChoiceChips(
                options: const [
                  (value: 'all', label: 'সব'),
                  (value: 'hub', label: 'হাব'),
                  (value: 'moving', label: 'পথে'),
                  (value: 'delivered', label: 'ডেলিভারি'),
                ],
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
              if (_error != null) ErrorNote(message: _error!, onRetry: _load),
              if (!_loading && _error == null && _visible(query).isEmpty)
                const EmptyNote(title: 'শিপমেন্ট নেই', body: 'নতুন শিপমেন্ট এলে এখানে দেখা যাবে।'),
              for (final row in _visible(query)) ...[
                _RowCard(row: row, admin: widget.role == UserRole.admin, onOpen: () => _open(row)),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<OperationalShipment> _visible(String query) {
    final rows = widget.role == UserRole.hub ? _hub : _admin;
    return [
      for (final row in rows)
        if (_matchesFilter(row) &&
            (query.isEmpty ||
                row.code.toLowerCase().contains(query) ||
                row.supplierCode.toLowerCase().contains(query) ||
                row.description.toLowerCase().contains(query) ||
                (row is AdminShipment && (row.supplierName ?? '').toLowerCase().contains(query))))
          row,
    ];
  }

  bool _matchesFilter(OperationalShipment row) {
    switch (_filter) {
      case 'hub':
        return row.status == 'received_bd_hub' || row.status == 'ready_for_last_mile' || row.status == 'out_for_delivery';
      case 'moving':
        return row.status == 'received_cn_hub' || row.status == 'ready_for_shipment' || row.status == 'in_transit' || row.status == 'customs_cleared';
      case 'delivered':
        return row.status == 'delivered';
      default:
        return true;
    }
  }

  void _open(OperationalShipment row) {
    final screen = switch (widget.role) {
      UserRole.hub => ShipmentProcessScreen(code: row.code),
      UserRole.admin => AdminShipmentScreen(code: row.code),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row, required this.admin, required this.onOpen});

  final OperationalShipment row;
  final bool admin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final current = row;
    final name = current is AdminShipment ? current.supplierName : null;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(row.code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              StatusPill(label: banglaStatus(row.status, row.statusLabel), tone: shipmentStatusTone(row.statusIndex)),
            ],
          ),
          const SizedBox(height: 6),
          Text(name == null || name.isEmpty ? row.supplierCode : '$name · ${row.supplierCode}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(row.description),
          const SizedBox(height: 4),
          Text('ওজন ${formatKg(row.effectiveKg)}'),
          if (admin && current is AdminShipment) Text('বাকি ${formatBdt(current.dueAmount)} · ${payStatusLabel(current.payStatus)}'),
          if (!admin) Text('পরের ধাপ: ${hubListStepLabel(hubListStep(row))}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          AppButton(label: admin ? 'ডিটেইল' : 'ধাপ খুলুন', kind: AppButtonKind.current, onPressed: onOpen),
        ],
      ),
    );
  }
}
