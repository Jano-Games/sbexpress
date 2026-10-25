import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer_activity.dart';
import '../../theme/app_colors.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';

class CustomerActivityScreen extends StatefulWidget {
  const CustomerActivityScreen(
      {super.key, required this.code, required this.name});

  final String code;
  final String name;

  @override
  State<CustomerActivityScreen> createState() => _CustomerActivityScreenState();
}

class _CustomerActivityScreenState extends State<CustomerActivityScreen> {
  CustomerActivityPage? _page;
  String? _error;
  var _loading = true;
  var _busy = false;
  var _pageNumber = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await AppScope.of(context)
          .customers
          .activity(widget.code, page: _pageNumber);
      if (!mounted) return;
      setState(() => _page = page);
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

  Future<void> _reverse(CustomerActivityEntry entry) async {
    final reason = await askReason(context, title: 'এন্ট্রি বাতিল');
    if (reason == null || !mounted) return;
    if (reason.length < 3) {
      setState(() => _error = 'বাতিলের কারণ কমপক্ষে ৩ অক্ষর।');
      return;
    }
    final ok = await confirmMoney(
      context,
      title: 'হিসাব বাতিল',
      body:
          '${activityLabel(entry.label)} ${formatBdt(entry.amount)} উল্টে দেওয়া হবে।',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context)
          .finance
          .reverse(kind: entry.reversalKind, id: entry.id, reason: reason);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final hasNext = page != null && page.page * page.limit < page.total;
    return WorkspaceScaffold(
        title: 'অ্যাকাউন্ট হিসাব',
        root: false,
        onRefresh: _load,
        subtitle: widget.code,
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  '${widget.name} · পেমেন্ট, অগ্রিম, ক্রেডিট ও রিফান্ড। মূল মুদ্রা আর BDT একসাথে।',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading && page == null)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ...[
            ErrorNote(message: _error!, onRetry: _load),
            const SizedBox(height: 12),
          ],
          if (page != null && page.entries.isEmpty)
            const EmptyNote(title: 'হিসাব নেই', body: 'টাকা নড়লে এখানে আসবে।'),
          if (page != null)
            for (final entry in page.entries) ...[
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activityLabel(entry.label),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(_when(entry.at),
                        style: const TextStyle(color: AppColors.muted)),
                    if (entry.reference.isNotEmpty)
                      Text(entry.reference,
                          style: const TextStyle(height: 1.35)),
                    if (entry.reason.isNotEmpty)
                      Text(entry.reason,
                          style: const TextStyle(
                              color: AppColors.muted, height: 1.35)),
                    const SizedBox(height: 8),
                    KvRow(
                        label: 'মূল',
                        value: formatMoney(
                            _signedSource(entry), entry.sourceCurrency)),
                    KvRow(label: 'BDT', value: formatBdt(entry.amount)),
                    if (entry.sourceCurrency == 'CNY')
                      KvRow(
                          label: 'রেট', value: '1 CNY = ${entry.sourceFxRate}'),
                    KvRow(
                        label: 'অ্যাকাউন্ট',
                        value: entry.accountName ?? 'ক্রেডিট ব্যালেন্স'),
                    if (entry.shipmentCode != null) ...[
                      const SizedBox(height: 8),
                      AppButton(
                        label: entry.shipmentCode!,
                        kind: AppButtonKind.quiet,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => AdminShipmentScreen(
                                  code: entry.shipmentCode!)),
                        ),
                      ),
                    ],
                    if (entry.canReverse) ...[
                      const SizedBox(height: 8),
                      AppButton(
                          label: 'বাতিল',
                          kind: AppButtonKind.danger,
                          busy: _busy,
                          onPressed: () => _reverse(entry)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          if (page != null && page.total > 0) ...[
            const SizedBox(height: 8),
            Text('${page.total} লাইন · পৃষ্ঠা ${page.page}',
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'আগের',
                    kind: AppButtonKind.quiet,
                    onPressed: page.page <= 1
                        ? null
                        : () {
                            setState(() => _pageNumber = page.page - 1);
                            _load();
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'পরের',
                    kind: AppButtonKind.quiet,
                    onPressed: hasNext
                        ? () {
                            setState(() => _pageNumber = page.page + 1);
                            _load();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ]);
  }

  double _signedSource(CustomerActivityEntry entry) {
    final sign = entry.amount < 0 ? -1.0 : 1.0;
    return sign * entry.sourceAmount.abs();
  }

  String _when(String at) {
    final text = at.replaceFirst('T', ' ');
    final dot = text.indexOf('.');
    return dot == -1 ? text : text.substring(0, dot);
  }
}
