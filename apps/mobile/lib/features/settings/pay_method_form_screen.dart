import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/pay_method_body.dart';
import '../../data/uploads/flutter_heic.dart';
import '../../data/uploads/image_prepare.dart';
import '../../data/uploads/picked_photo_file.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/team_parts.dart';
import '../../widgets/ui.dart';

class PayMethodFormScreen extends StatefulWidget {
  const PayMethodFormScreen({super.key, this.initialKind = 'mobile_banking'});

  /// `mobile_banking` or `bank_account`.
  final String initialKind;

  @override
  State<PayMethodFormScreen> createState() => _PayMethodFormScreenState();
}

class _PayMethodFormScreenState extends State<PayMethodFormScreen> {
  final _provider = TextEditingController(text: 'bKash');
  final _number = TextEditingController();
  final _label = TextEditingController();
  final _note = TextEditingController();
  final _bank = TextEditingController();
  final _accountNumber = TextEditingController();
  final _holder = TextEditingController();
  final _branch = TextEditingController();
  final _district = TextEditingController();
  late var _kind = widget.initialKind;
  var _currency = 'BDT';
  String? _qr;
  String? _error;
  var _busy = false;

  static const _providers = ['bKash', 'Nagad', 'Rocket'];

  @override
  void dispose() {
    _provider.dispose();
    _number.dispose();
    _label.dispose();
    _note.dispose();
    _bank.dispose();
    _accountNumber.dispose();
    _holder.dispose();
    _branch.dispose();
    _district.dispose();
    super.dispose();
  }

  Future<void> _qrPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    try {
      final prepared = await prepareForUpload(
        Uint8List.fromList(await file.readAsBytes()),
        name: file.name,
        mime: file.mimeType,
        decodeHeic: flutterDecodeHeic,
      );
      final url = jpegQrDataUrl(prepared.bytes);
      if (!mounted) return;
      if (url == null) {
        setState(() => _error = tr(
            'The QR image could not be brought under 300 KB. Choose a smaller image.'));
        return;
      }
      setState(() {
        _qr = url;
        _error = null;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      await deletePickedPhotoFile(file.path);
    }
  }

  /// The fund account the server creates beside the method.
  String get _fund => _kind == 'mobile_banking'
      ? '${_provider.text.trim()} · ${_number.text.trim()}'
      : '${_bank.text.trim()} · ${_accountNumber.text.trim()}';

  Future<void> _save() async {
    final Map<String, Object?> body;
    if (_kind == 'mobile_banking') {
      if (_provider.text.trim().isEmpty || _number.text.trim().isEmpty) {
        setState(() => _error =
            tr('Enter the provider and number. Do not guess the number.'));
        return;
      }
      body = mobilePayMethodBody(
        provider: _provider.text,
        number: _number.text,
        label: _label.text,
        note: _note.text,
        currency: _currency,
        qrImage: _qr,
      );
    } else {
      if (_bank.text.trim().isEmpty ||
          _accountNumber.text.trim().isEmpty ||
          _holder.text.trim().isEmpty) {
        setState(() => _error =
            tr('Enter the bank, account number and account holder name.'));
        return;
      }
      body = bankPayMethodBody(
        bankName: _bank.text,
        accountNumber: _accountNumber.text,
        accountName: _holder.text,
        branch: _branch.text,
        district: _district.text,
        currency: _currency,
      );
    }
    final fund = _fund;
    final ok = await confirmMoney(context,
        title: tr('Payment method'),
        body: tr(
            'It will show on the tracking page and a fund account will be created: {fund} ({currency}).',
            {'fund': fund, 'currency': _currency}));
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).settings.createPayMethod(body);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changed(String _) => setState(() {});

  Widget _field(String label, TextEditingController controller,
          {String? helper,
          TextInputType? keyboard,
          bool strong = false,
          bool optional = false,
          int? maxLength,
          int maxLines = 1}) =>
      LabeledField(
          label: label,
          helper: helper,
          optional: optional,
          child: TextField(
              controller: controller,
              onChanged: _changed,
              keyboardType: keyboard,
              maxLength: maxLength,
              minLines: maxLines > 1 ? 2 : null,
              maxLines: maxLines,
              style: strong
                  ? const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)
                  : null));

  @override
  Widget build(BuildContext context) {
    final mobile = _kind == 'mobile_banking';
    final fund = _fund;
    final hint = tr(
        'Saving also creates the fund account {fund} ({currency}). It is blocked if a fund with this number already exists.',
        {'currency': _currency}).split('{fund}');
    return WorkspaceScaffold(
        title: tr('New payment method'),
        subtitle: tr('Shown on the customer tracking page'),
        root: false,
        footer: FooterActions(
            error: _error,
            child: AppButton(
                label: tr('Save method'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          PairRow(
            flex: const [17, 10],
            first: LabeledField(
                label: tr('Type'),
                child: SegmentPicker<String>(
                    flex: const [135, 100],
                    oneLine: true,
                    options: [
                      (
                        value: 'mobile_banking',
                        label: tr('bKash / mobile'),
                        icon: Icons.smartphone_rounded
                      ),
                      (
                        value: 'bank_account',
                        label: tr('Bank'),
                        icon: Icons.account_balance_outlined
                      ),
                    ],
                    selected: _kind,
                    onChanged: (value) => setState(() => _kind = value))),
            second: LabeledField(
                label: tr('Currency'),
                child: SegmentPicker<String>(
                    oneLine: true,
                    options: const [
                      (value: 'BDT', label: 'BDT', icon: null),
                      (value: 'CNY', label: 'CNY', icon: null),
                    ],
                    selected: _currency,
                    onChanged: (value) => setState(() => _currency = value))),
          ),
          const SizedBox(height: 16),
          if (mobile)
            FormCard(children: [
              LabeledField(
                  label: tr('Provider'),
                  helper: tr('Pick one above, or type another provider.'),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TickChips(
                            options: _providers,
                            selected: _provider.text.trim(),
                            onSelected: (value) =>
                                setState(() => _provider.text = value)),
                        const SizedBox(height: 8),
                        TextField(controller: _provider, onChanged: _changed),
                      ])),
              _field(tr('Number'), _number,
                  helper: tr('Copy it from the account. Do not guess.'),
                  keyboard: TextInputType.phone,
                  strong: true),
              _field(tr('Label (optional)'), _label, optional: true),
              _field(tr('Note (optional)'), _note,
                  optional: true, maxLength: 200, maxLines: 3),
              _QrBox(
                  added: _qr != null,
                  onChoose: _qrPhoto,
                  onRemove: () => setState(() => _qr = null)),
            ])
          else
            FormCard(children: [
              _field(tr('Bank name'), _bank),
              _field(tr('Account number'), _accountNumber,
                  helper: tr('Copy it from the account. Do not guess.'),
                  keyboard: TextInputType.number,
                  strong: true),
              _field(tr('Account holder'), _holder),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: _field(tr('Branch (optional)'), _branch,
                        optional: true)),
                const SizedBox(width: 10),
                Expanded(
                    child: _field(tr('District (optional)'), _district,
                        optional: true)),
              ]),
            ]),
          const SizedBox(height: 22),
          SectionTitle(
              title: tr('How customers see it'),
              action: StatusPill(label: tr('Preview'), tone: ChipTone.neutral)),
          _Preview(
              title: mobile ? _provider.text.trim() : _bank.text.trim(),
              currency: _currency,
              numberLabel: mobile ? tr('Payment number') : tr('Account number'),
              number: mobile ? _number.text.trim() : _accountNumber.text.trim(),
              lines: mobile
                  ? [_note.text.trim()]
                  : [
                      _holder.text.trim(),
                      [_branch.text.trim(), _district.text.trim()]
                          .where((part) => part.isNotEmpty)
                          .join(' · '),
                    ],
              qr: mobile && _qr != null),
          const SizedBox(height: 14),
          TipNote(
              rich: TextSpan(children: [
            TextSpan(text: hint.first),
            TextSpan(
                text: fund.trim() == '·' ? '…' : fund,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (hint.length > 1) TextSpan(text: hint.sublist(1).join()),
          ])),
        ]);
  }
}

class _QrBox extends StatelessWidget {
  const _QrBox(
      {required this.added, required this.onChoose, required this.onRemove});
  final bool added;
  final VoidCallback onChoose, onRemove;

  @override
  Widget build(BuildContext context) => DashedOutline(
      background: const Color(0xFFF8FAFC),
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: added ? AppColors.okSoft : AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line)),
                child: Icon(
                    added ? Icons.check_rounded : Icons.qr_code_2_rounded,
                    size: 22,
                    color: added ? AppColors.ok : AppColors.inkSoft)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  added
                      ? Text(tr('QR added'),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600))
                      : FieldLabel(tr('QR image (optional)'), optional: true),
                  Text(tr('From the gallery, kept under 300 KB'),
                      style: const TextStyle(
                          fontSize: 12, height: 1.4, color: AppColors.muted)),
                ])),
            const SizedBox(width: 8),
            if (added)
              TextButton(
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: onRemove,
                  child: Text(tr('Remove QR')))
            else
              OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.card,
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                          fontFamily: 'HindSiliguri',
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  onPressed: onChoose,
                  child: Text(tr('Choose'))),
          ])));
}

/// What the customer tracking page shows for this method.
class _Preview extends StatelessWidget {
  const _Preview(
      {required this.title,
      required this.currency,
      required this.numberLabel,
      required this.number,
      required this.lines,
      required this.qr});
  final String title, currency, numberLabel, number;
  final List<String> lines;
  final bool qr;

  @override
  Widget build(BuildContext context) {
    final extra = lines.where((line) => line.isNotEmpty).toList();
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: AppColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title.isEmpty ? '—' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700))),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.field)),
                child: Text(currency,
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft))),
          ]),
          const SizedBox(height: 10),
          Text(numberLabel,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 4),
          Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Expanded(
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(number.isEmpty ? '—' : number,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                fontFeatures: [
                                  FontFeature.tabularFigures()
                                ])))),
                const ExcludeSemantics(
                    child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.copy_rounded,
                            size: 17, color: AppColors.inkSoft))),
              ])),
          for (final line in extra) ...[
            const SizedBox(height: 6),
            Text(line,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: AppColors.inkSoft)),
          ],
          if (qr) ...[
            const SizedBox(height: 8),
            InfoChip(icon: Icons.qr_code_2_rounded, label: tr('QR added')),
          ],
        ]));
  }
}
