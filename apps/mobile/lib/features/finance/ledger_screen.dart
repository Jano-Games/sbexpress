import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/ledger_actions.dart';
import '../../theme/app_colors.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  List<LedgerEntry> _entries = const [];
  String? _error;
  var _loading = true;
  var _busy = false;

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
      final entries = await AppScope.of(context).finance.ledger();
      if (!mounted) return;
      setState(() => _entries = entries);
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

  Future<void> _reverse(LedgerEntry entry) async {
    final reason = await askReason(context, title: 'এন্ট্রি বাতিল');
    if (reason == null || !mounted) return;
    if (reason.length < 3) {
      setState(() => _error = 'বাতিলের কারণ কমপক্ষে ৩ অক্ষর।');
      return;
    }
    final ok = await confirmMoney(context,
        title: 'লেজার বাতিল',
        body:
            '${entry.description} উল্টে দেওয়া হবে। টাকা আগের অ্যাকাউন্টে ফিরবে।');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).finance.reverse(
          kind: entry.reversalKind, id: entry.recordId, reason: reason);
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
    final seen = <String>{};
    return WorkspaceScaffold(
        title: 'লেজার',
        root: false,
        onRefresh: _load,
        children: [
          const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                  'সাম্প্রতিক ৫০টি লাইন। ট্রান্সফারের দুই পাশ একবার বাতিল হয়।',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading && _entries.isEmpty)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ...[
            ErrorNote(message: _error!, onRetry: _load),
            const SizedBox(height: 12),
          ],
          if (!_loading && _entries.isEmpty)
            const EmptyNote(title: 'লাইন নেই', body: 'টাকা নড়লে এখানে আসবে।'),
          for (final entry in _entries) ...[
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.description,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${entry.account ?? '—'} · ${entry.reversalKind}',
                      style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Text(formatMoney(entry.amount, entry.currency),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (entry.canReverse &&
                      seen.add('${entry.reversalKind}:${entry.recordId}')) ...[
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
        ]);
  }
}
