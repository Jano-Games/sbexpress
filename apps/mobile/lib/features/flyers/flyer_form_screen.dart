import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flyer.dart';
import '../../data/uploads/photo_upload.dart';
import '../../data/uploads/quick_uploads.dart';
import '../../data/uploads/upload_queue.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart' show MeterBar;
import '../../widgets/quick_parts.dart';
import '../../widgets/team_parts.dart';
import '../../widgets/ui.dart';
import 'flyer_detail_screen.dart';

/// New flyer: profile and travel documents in one go. The documents are
/// sent right after the flyer is saved, then the flyer's page opens.
class FlyerFormScreen extends StatefulWidget {
  const FlyerFormScreen({super.key, this.pickFile});

  /// Picks one document photo or PDF; null when cancelled. Tests replace it.
  final Future<PickedPhoto?> Function(FileSource source)? pickFile;

  @override
  State<FlyerFormScreen> createState() => _FlyerFormScreenState();
}

/// The documents asked for on the form, as the server's kinds.
const _documentKinds = ['student_id', 'visa', 'admission'];

class _FlyerFormScreenState extends State<FlyerFormScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _bd = TextEditingController();
  final _cn = TextEditingController();
  final _university = TextEditingController();
  final _batch = TextEditingController();
  final _program = TextEditingController();
  final _wechat = TextEditingController();
  final _emergency = TextEditingController();
  final _files = <String, PickedPhoto>{};
  UploadQueue? _uploads;
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    for (final controller in [
      _first,
      _last,
      _bd,
      _cn,
      _university,
      _batch,
      _program,
      _wechat,
      _emergency
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _title(String kind) => switch (kind) {
        'student_id' => tr('Student ID'),
        'visa' => tr('Visa'),
        _ => tr('Admission letter'),
      };

  static IconData _icon(String kind) => switch (kind) {
        'student_id' => Icons.badge_outlined,
        'visa' => Icons.travel_explore_outlined,
        _ => Icons.description_outlined,
      };

  Future<void> _pick(String kind, FileSource source) async {
    try {
      final file = await (widget.pickFile ?? pickDocument)(source);
      if (file == null || !mounted) return;
      final problem = pdfProblem(file);
      setState(() {
        _error = problem;
        if (problem == null) _files[kind] = file;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty) {
      setState(() => _error = tr('Enter the first name.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final scope = AppScope.of(context);
      final name = await scope.flyers.create(FlyerDraft(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        bdPhone: _bd.text.trim(),
        cnPhone: _cn.text.trim(),
        university: _university.text.trim(),
        batch: _batch.text.trim(),
        program: _program.text.trim(),
        wechat: _wechat.text.trim(),
        emergencyContact: _emergency.text.trim(),
      ));
      UploadQueue? uploads;
      if (_files.isNotEmpty) {
        uploads = UploadQueue([
          for (final kind in _documentKinds)
            if (_files[kind] case final file?)
              flyerDocumentJob(scope.flyers, name, kind, file),
        ]);
        if (mounted) setState(() => _uploads = uploads);
        await uploads.start();
      }
      if (!mounted) return;
      // The list that opened the form reloads on `true`.
      await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
              builder: (_) => FlyerDetailScreen(name: name, uploads: uploads)),
          result: true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, TextEditingController controller,
          {TextInputType? keyboard,
          TextCapitalization caps = TextCapitalization.none,
          String? hint}) =>
      LabeledField(
          label: label,
          child: TextField(
              controller: controller,
              keyboardType: keyboard,
              textCapitalization: caps,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(hintText: hint)));

  @override
  Widget build(BuildContext context) {
    final count = _files.length;
    final uploads = _uploads;
    return WorkspaceScaffold(
        title: tr('New flyer'),
        subtitle: tr('Profile and travel documents in one go'),
        root: false,
        footer: FooterActions(
            error: _error,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (uploads != null)
                    ListenableBuilder(
                        listenable: uploads,
                        builder: (context, _) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(children: [
                              Expanded(
                                  child: MeterBar(value: uploads.progress)),
                              const SizedBox(width: 10),
                              Text(
                                  tr('Uploading {done} of {total}', {
                                    'done': uploads.doneCount,
                                    'total': uploads.total
                                  }),
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.muted)),
                            ]))),
                  AppButton(
                      key: const Key('flyer-save'),
                      label: count == 0
                          ? tr('Save flyer')
                          : trn(count, 'Save flyer and upload {n} file',
                              'Save flyer and upload {n} files'),
                      icon: count == 0
                          ? Icons.check_rounded
                          : Icons.upload_rounded,
                      kind: AppButtonKind.current,
                      busy: _busy,
                      onPressed: _save),
                ])),
        children: [
          FormCard(title: tr('Personal details'), children: [
            PairRow(
                first: _field(tr('First name'), _first,
                    caps: TextCapitalization.words),
                second: _field(tr('Last name'), _last,
                    caps: TextCapitalization.words)),
          ]),
          const SizedBox(height: 14),
          FormCard(title: tr('Contact'), children: [
            PairRow(
                first: _field(tr('Bangladesh phone'), _bd,
                    keyboard: TextInputType.phone),
                second: _field(tr('China phone'), _cn,
                    keyboard: TextInputType.phone, hint: '+86')),
            PairRow(
                first: _field('WeChat', _wechat),
                second: _field(tr('Emergency contact'), _emergency)),
          ]),
          const SizedBox(height: 14),
          FormCard(title: tr('Study'), children: [
            _field(tr('University'), _university),
            PairRow(
                first: _field(tr('Program'), _program),
                second: _field(tr('Batch'), _batch)),
          ]),
          const SizedBox(height: 14),
          PaperCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(tr('Documents'),
                          style: const TextStyle(
                              fontSize: 16,
                              height: 1.35,
                              fontWeight: FontWeight.w700))),
                  Text(
                      tr('{n} of {total} added',
                          {'n': count, 'total': _documentKinds.length}),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ]),
                for (final kind in _documentKinds) ...[
                  const SizedBox(height: 12),
                  DocumentSlot(
                      key: ValueKey('flyer-doc-$kind'),
                      title: _title(kind),
                      icon: _icon(kind),
                      file: _files[kind],
                      onPick: (source) => _pick(kind, source),
                      onRemove: () => setState(() => _files.remove(kind))),
                ],
                const SizedBox(height: 12),
                TipNote(
                    text: tr(
                        "Files upload right after the flyer is saved. Optional — you can add them later on the flyer's page too.")),
              ])),
        ]);
  }
}
