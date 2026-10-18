import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/hub/hub_chain.dart';
import '../../data/models/session_user.dart';
import '../../data/models/shipment.dart';
import '../../data/repositories/shipment_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
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
              const Text('Shipment', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'কোড বা কার্গো'),
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
    if (query.isEmpty) return rows;
    return [
      for (final row in rows)
        if (row.code.toLowerCase().contains(query) ||
            row.supplierCode.toLowerCase().contains(query) ||
            row.description.toLowerCase().contains(query) ||
            (row is AdminShipment && (row.supplierName ?? '').toLowerCase().contains(query)))
          row,
    ];
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
              StatusPill(label: banglaStatus(row.status, row.statusLabel)),
            ],
          ),
          const SizedBox(height: 6),
          Text(name == null || name.isEmpty ? row.supplierCode : '$name · ${row.supplierCode}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(row.description),
          const SizedBox(height: 4),
          Text('ওজন ${formatKg(row.effectiveKg)}'),
          if (!admin) Text('পরের ধাপ: ${hubListStepLabel(hubListStep(row))}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          AppButton(label: admin ? 'ডিটেইল' : 'ধাপ খুলুন', kind: AppButtonKind.current, onPressed: onOpen),
        ],
      ),
    );
  }
}
