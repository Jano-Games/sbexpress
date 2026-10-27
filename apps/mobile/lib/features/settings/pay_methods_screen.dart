import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/workspace.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/team_parts.dart';
import '../../widgets/ui.dart';
import 'pay_method_form_screen.dart';

/// bKash numbers and bank accounts shown on customer links; each can be
/// hidden or shown, and new ones added.
class PayMethodsScreen extends StatefulWidget {
  const PayMethodsScreen({super.key});

  @override
  State<PayMethodsScreen> createState() => _PayMethodsScreenState();
}

class _PayMethodsScreenState extends State<PayMethodsScreen> {
  List<PayMethodInfo> _methods = const [];
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
      final methods = await AppScope.of(context).settings.payMethods();
      if (!mounted) return;
      setState(() => _methods = methods);
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

  Future<void> _toggle(PayMethodInfo method) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context)
          .settings
          .setPayMethodEnabled(method.id, enabled: !method.enabled);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newMethod() async {
    final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PayMethodFormScreen()));
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => WorkspaceScaffold(
          title: tr('Payment methods'),
          subtitle: tr('Shown on the customer link'),
          root: false,
          onRefresh: _load,
          actions: [
            Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                    child: BarPillButton(
                        label: tr('New'), onPressed: _newMethod))),
          ],
          children: [
            if (_loading && _methods.isEmpty) const LinearProgressIndicator(),
            if (_error != null) ErrorNote(message: _error!, onRetry: _load),
            if (!_loading && _methods.isEmpty && _error == null)
              EmptyNote(
                  icon: Icons.account_balance_wallet_outlined,
                  title: tr('No methods'),
                  body: tr('Add bKash, bank or wallet details.'))
            else if (_methods.isNotEmpty)
              SurfaceGroup(children: [
                for (final method in _methods)
                  _MethodRow(
                      method: method,
                      onChanged: _busy ? null : (_) => _toggle(method)),
              ]),
          ]);
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({required this.method, required this.onChanged});
  final PayMethodInfo method;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bank = method.kind == 'bank_account';
    final detail = [
      method.currency,
      bank
          ? tr('bank account')
          : method.number.isEmpty
              ? method.provider
              : method.number,
      if (!method.enabled) tr('hidden'),
    ].join(' · ');
    return Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          IconBadge(
              bank ? Icons.account_balance_outlined : Icons.smartphone_rounded,
              tone: method.enabled ? ChipTone.blue : ChipTone.neutral),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(method.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: method.enabled
                            ? AppColors.ink
                            : AppColors.inkSoft)),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.muted)),
              ])),
          const SizedBox(width: 8),
          Semantics(
              label: method.title,
              child: Switch(value: method.enabled, onChanged: onChanged)),
        ]));
  }
}
