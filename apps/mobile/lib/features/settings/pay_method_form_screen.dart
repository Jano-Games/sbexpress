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
import '../../widgets/ui.dart';

class PayMethodFormScreen extends StatefulWidget {
  const PayMethodFormScreen({super.key});

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
  var _kind = 'mobile_banking';
  var _currency = 'BDT';
  String? _qr;
  String? _error;
  var _busy = false;

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

  Future<void> _save() async {
    final Map<String, Object?> body;
    final String fund;
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
      fund = '${_provider.text.trim()} · ${_number.text.trim()}';
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
      fund = '${_bank.text.trim()} · ${_accountNumber.text.trim()}';
    }
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

  @override
  Widget build(BuildContext context) {
    final mobile = _kind == 'mobile_banking';
    return WorkspaceScaffold(
        title: tr('New payment method'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save method'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'Customers see this number on the tracking page. The server blocks it if a fund with the same number already exists.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          ChoiceChips(
            options: [
              (value: 'mobile_banking', label: tr('bKash / mobile')),
              (value: 'bank_account', label: tr('Bank'))
            ],
            selected: _kind,
            onSelected: (value) => setState(() => _kind = value),
          ),
          const SizedBox(height: 12),
          SectionTitle(title: tr('Currency')),
          ChoiceChips(
            options: const [
              (value: 'BDT', label: 'BDT'),
              (value: 'CNY', label: 'CNY')
            ],
            selected: _currency,
            onSelected: (value) => setState(() => _currency = value),
          ),
          const SizedBox(height: 12),
          if (mobile) ...[
            ChoiceChips(
              options: const [
                (value: 'bKash', label: 'bKash'),
                (value: 'Nagad', label: 'Nagad'),
                (value: 'Rocket', label: 'Rocket'),
              ],
              selected:
                  const {'bKash', 'Nagad', 'Rocket'}.contains(_provider.text)
                      ? _provider.text
                      : '',
              onSelected: (value) => setState(() => _provider.text = value),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _provider,
                decoration: InputDecoration(labelText: tr('Provider'))),
            const SizedBox(height: 8),
            TextField(
                controller: _number,
                decoration: InputDecoration(labelText: tr('Number'))),
            const SizedBox(height: 8),
            TextField(
                controller: _label,
                decoration: InputDecoration(labelText: tr('Label (optional)'))),
            const SizedBox(height: 8),
            TextField(
                controller: _note,
                maxLength: 200,
                decoration: InputDecoration(labelText: tr('Note (optional)'))),
            const SizedBox(height: 8),
            AppButton(
                label: _qr == null ? tr('QR image (optional)') : tr('QR added'),
                kind: AppButtonKind.quiet,
                onPressed: _qrPhoto),
            if (_qr != null)
              TextButton(
                  onPressed: () => setState(() => _qr = null),
                  child: Text(tr('Remove QR'))),
          ] else ...[
            TextField(
                controller: _bank,
                decoration: InputDecoration(labelText: tr('Bank name'))),
            const SizedBox(height: 8),
            TextField(
                controller: _accountNumber,
                decoration: InputDecoration(labelText: tr('Account number'))),
            const SizedBox(height: 8),
            TextField(
                controller: _holder,
                decoration: InputDecoration(labelText: tr('Account holder'))),
            const SizedBox(height: 8),
            TextField(
                controller: _branch,
                decoration:
                    InputDecoration(labelText: tr('Branch (optional)'))),
            const SizedBox(height: 8),
            TextField(
                controller: _district,
                decoration:
                    InputDecoration(labelText: tr('District (optional)'))),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
        ]);
  }
}
