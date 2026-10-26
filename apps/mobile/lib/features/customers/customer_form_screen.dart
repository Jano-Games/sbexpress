import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/quick_parts.dart';
import '../../widgets/team_parts.dart';
import '../../widgets/ui.dart';

/// New customer: the code first (filled with the next free one), then name,
/// phone, address and how the customer usually pays.
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  var _terms = 'instant';

  /// The code the server suggested; null until it answers or when it cannot.
  String? _suggested;
  var _askedForCode = false;
  String? _codeError;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCode();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  /// An older server has no next-code route; the field then stays empty and
  /// the server picks the code on save.
  Future<void> _loadCode() async {
    try {
      final code = await AppScope.of(context).customers.nextCode();
      if (!mounted) return;
      setState(() {
        _suggested = code;
        if (_code.text.trim().isEmpty) _code.text = code;
      });
    } catch (_) {
      // Leave the field empty.
    } finally {
      if (mounted) setState(() => _askedForCode = true);
    }
  }

  bool get _auto => _suggested != null && _code.text.trim() == _suggested;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = tr('Enter the customer name.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _codeError = null;
    });
    try {
      final typed = _code.text.trim();
      await AppScope.of(context).customers.create(CustomerDraft(
            // The suggested code is left to the server, so two people adding
            // customers at once never clash on it.
            code: typed.isEmpty || _auto ? null : typed,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
            terms: _terms,
          ));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      final used =
          RegExp(r'Customer (.+) already exists').firstMatch(error.message);
      setState(() {
        if (error.status == 400 && used != null) {
          _codeError = tr('{code} is already used by another customer.',
              {'code': used.group(1)});
        } else {
          _error = error.message;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auto = _auto;
    return WorkspaceScaffold(
        title: tr('New customer'),
        root: false,
        footer: FooterActions(
            error: _error,
            child: AppButton(
                key: const Key('customer-save'),
                label: tr('Save customer'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          FormCard(children: [
            LabeledField(
                label: tr('Customer code'),
                helper: _codeError == null
                    ? _suggested != null
                        ? tr(
                            'The next free code. Type your own if you prefer — it must not be used already.')
                        : _askedForCode
                            ? tr('Leave empty for an automatic code')
                            : null
                    : null,
                child: TextField(
                    key: const Key('customer-code'),
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    onChanged: (_) => setState(() => _codeError = null),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3),
                    decoration: InputDecoration(
                        hintText: _suggested == null
                            ? tr('Leave empty for an automatic code')
                            : null,
                        errorText: _codeError,
                        errorMaxLines: 3,
                        suffixIcon: auto
                            ? Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(end: 10),
                                child: Center(
                                    widthFactor: 1,
                                    child: StatusPill(
                                        label: tr('Auto'),
                                        tone: ChipTone.blue)))
                            : null))),
            LabeledField(
                label: tr('Name'),
                child: TextField(
                    key: const Key('customer-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        InputDecoration(hintText: tr('Shop or person name')))),
            LabeledField(
                label: tr('Phone'),
                child: TextField(
                    key: const Key('customer-phone'),
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(hintText: '01XXXXXXXXX'))),
            LabeledField(
                label: tr('Address'),
                child: TextField(
                    key: const Key('customer-address'),
                    controller: _address,
                    minLines: 1,
                    maxLines: 3,
                    decoration:
                        InputDecoration(hintText: tr('House, road and area')))),
          ]),
          const SizedBox(height: 18),
          SectionTitle(title: tr('How does this customer usually pay?')),
          TileRow(children: [
            ChoiceTile(
                key: const Key('customer-terms-instant'),
                title: tr('After delivery'),
                subtitle: tr('Pays for each shipment once it arrives'),
                selected: _terms == 'instant',
                onTap: () => setState(() => _terms = 'instant')),
            ChoiceTile(
                key: const Key('customer-terms-monthly'),
                title: tr('Monthly'),
                subtitle: tr('One bill for the whole month'),
                selected: _terms == 'monthly',
                onTap: () => setState(() => _terms = 'monthly')),
          ]),
          const SizedBox(height: 10),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                  tr(
                      'New bookings for this customer start with this choice; each booking can still change it.'),
                  style: const TextStyle(
                      fontSize: 12, height: 1.45, color: AppColors.muted))),
        ]);
  }
}
