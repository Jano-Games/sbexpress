import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/flyer.dart';
import '../../data/share_bytes.dart';
import '../../data/uploads/flutter_heic.dart';
import '../../data/uploads/image_prepare.dart';
import '../../data/uploads/picked_photo_file.dart';
import '../../data/uploads/photo_upload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../flights/flight_detail_screen.dart';
import '../pdf/pdf_bytes_screen.dart';

class FlyerDetailScreen extends StatefulWidget {
  const FlyerDetailScreen({super.key, required this.name});

  final String name;

  @override
  State<FlyerDetailScreen> createState() => _FlyerDetailScreenState();
}

class _FlyerDetailScreenState extends State<FlyerDetailScreen> {
  FlyerDetail? _flyer;
  FlyerDocumentList? _documents;
  String? _error;
  var _loading = true;
  var _tab = 0;
  var _busy = false;
  var _kind = 'student_id';
  PhotoUploadController? _photos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _photos ??= PhotoUploadController(
      decodeHeic: flutterDecodeHeic,
      upload: (image, progress) => AppScope.of(context).flyers.uploadDocument(
          name: widget.name, kind: _kind, image: image, onProgress: progress),
    )..addListener(() {
        if (mounted) setState(() {});
        if (_photos?.done == true) _load();
      });
  }

  @override
  void dispose() {
    _photos?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = AppScope.of(context);
      final flyer = await scope.flyers.detail(widget.name);
      final documents = await scope.flyers.documents(widget.name);
      if (!mounted) return;
      setState(() {
        _flyer = flyer;
        _documents = documents;
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

  Future<void> _archive() async {
    final flyer = _flyer;
    if (flyer == null) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context)
          .flyers
          .archive(flyer.name, archived: !flyer.archived);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify(FlyerDocument document, bool verified) async {
    try {
      await AppScope.of(context)
          .flyers
          .setVerified(widget.name, document.reference, verified: verified);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  Future<List<int>?> _loadDocument(FlyerDocument document) async {
    setState(() => _busy = true);
    try {
      final url = await AppScope.of(context)
          .flyers
          .documentUrl(widget.name, document.reference);
      return await downloadUrl(url);
    } on ApiException catch (error) {
      if (mounted && error.status != 401) {
        setState(() => _error = error.message);
      }
      return null;
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewDocument(FlyerDocument document) async {
    final bytes = await _loadDocument(document);
    if (!mounted || bytes == null) return;
    await openPdf(context,
        title: document.name, filename: document.name, bytes: bytes);
  }

  Future<void> _shareDocument(FlyerDocument document) async {
    final bytes = await _loadDocument(document);
    if (!mounted || bytes == null) return;
    final mime = document.contentType.isEmpty
        ? 'application/octet-stream'
        : document.contentType;
    try {
      await shareBytes(bytes: bytes, filename: document.name, mimeType: mime);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _pickPdf() async {
    final picked = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: const ['pdf']);
    if (picked.isEmpty) return;
    final file = picked.single;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > imageUploadMaxBytes) {
      setState(
          () => _error = tr('The PDF is over 10 MB. Choose a smaller file.'));
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).flyers.uploadPdf(
          name: widget.name,
          kind: _kind,
          filename: file.name,
          bytes: bytes,
          onProgress: (_) {});
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return;
    try {
      await _photos?.select(PickedPhoto(
          bytes: await file.readAsBytes(),
          name: file.name,
          mime: file.mimeType));
    } finally {
      await deletePickedPhotoFile(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flyer = _flyer;
    final documents = _documents;
    final upload = _photos;
    return Scaffold(
      appBar: BackTitle(title: widget.name),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(pageGutter, 12, pageGutter, 32),
          children: [
            if (_loading && flyer == null)
              const LinearProgressIndicator(
                  color: AppColors.teal, backgroundColor: AppColors.tealSoft),
            if (_error != null) ...[
              ErrorNote(message: _error!, onRetry: _load),
              const SizedBox(height: 12),
            ],
            if (flyer != null) ...[
              ScreenTabs(
                  labels: [tr('Profile'), tr('Flights'), tr('Documents')],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i)),
              const SizedBox(height: 20),
              if (_tab == 0) ...[
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(flyer.name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                          '${flyer.university} · ${flyer.program} · ${flyer.batch}'),
                      Text('BD ${flyer.bdPhone} · CN ${flyer.cnPhone}'),
                      Text('WeChat ${flyer.wechat}'),
                      Text(
                          tr('Emergency {contact}',
                              {'contact': flyer.emergencyContact}),
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StatusPill(
                              label: flyer.docStudentId
                                  ? tr('Student ID')
                                  : tr('ID pending'),
                              tone: flyer.docStudentId
                                  ? ChipTone.green
                                  : ChipTone.amber),
                          StatusPill(
                              label: flyer.docVisa
                                  ? tr('Visa')
                                  : tr('Visa pending'),
                              tone: flyer.docVisa
                                  ? ChipTone.green
                                  : ChipTone.amber),
                          StatusPill(
                              label: flyer.docAdmission
                                  ? tr('Admission')
                                  : tr('Admission pending'),
                              tone: flyer.docAdmission
                                  ? ChipTone.green
                                  : ChipTone.neutral),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(tr('Total booked {kg} kg',
                          {'kg': flyer.totalKg.toStringAsFixed(1)})),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: flyer.archived
                      ? tr('Reactivate flyer')
                      : tr('Archive flyer'),
                  kind: flyer.archived
                      ? AppButtonKind.teal
                      : AppButtonKind.danger,
                  busy: _busy,
                  onPressed: _archive,
                ),
              ],
              if (_tab == 1) ...[
                const SizedBox(height: 16),
                SectionTitle(title: tr('Flights')),
                if (flyer.flights.isEmpty)
                  EmptyNote(
                      title: tr('No flights'),
                      body:
                          tr('Flights appear here once created or assigned.')),
                for (final flight in flyer.flights) ...[
                  DirectoryTile(
                    title: displayFlightCode(flight.code),
                    subtitle:
                        '${flight.date} · ${flight.depTime}–${flight.arrTime} · ${flight.bookedKg.toStringAsFixed(1)} / ${flight.spaceKg} kg',
                    badge: flight.statusLabel,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                FlightDetailScreen(code: flight.code))),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (_tab == 2) ...[
                const SizedBox(height: 8),
                SectionTitle(
                    title: tr('Documents'),
                    subtitle: tr('Add ID, visa and other travel documents.')),
                if (documents != null && !documents.configured)
                  ErrorNote(
                      message: tr(
                          'Storage is not set up yet. Uploads are off until setup is complete.')),
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  decoration: InputDecoration(labelText: tr('Type')),
                  items: [
                    for (final entry in flyerDocumentKinds.entries)
                      DropdownMenuItem(
                          value: entry.key, child: Text(entry.value))
                  ],
                  onChanged: documents?.configured == false
                      ? null
                      : (value) => setState(() => _kind = value ?? _kind),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: AppButton(
                            label: tr('Camera'),
                            kind: AppButtonKind.quiet,
                            onPressed: documents?.configured == false
                                ? null
                                : () => _pick(ImageSource.camera))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: AppButton(
                            label: tr('Gallery'),
                            kind: AppButtonKind.quiet,
                            onPressed: documents?.configured == false
                                ? null
                                : () => _pick(ImageSource.gallery))),
                  ],
                ),
                const SizedBox(height: 8),
                AppButton(
                    label: tr('Upload PDF'),
                    kind: AppButtonKind.teal,
                    busy: _busy,
                    onPressed:
                        documents?.configured == false ? null : _pickPdf),
                if (upload != null && upload.busy)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                        value: upload.progress == 0 ? null : upload.progress,
                        color: AppColors.teal,
                        backgroundColor: AppColors.tealSoft),
                  ),
                if (upload?.error != null) ...[
                  const SizedBox(height: 8),
                  Text(upload!.error!,
                      style: const TextStyle(color: AppColors.danger)),
                  AppButton(
                      label: tr('Send the same photo again'),
                      onPressed: upload.retry),
                ],
                const SizedBox(height: 12),
                if (documents == null || documents.documents.isEmpty)
                  EmptyNote(
                      title: tr('No documents'),
                      body: tr('Verified files will appear here.'))
                else
                  for (final document in documents.documents) ...[
                    PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(document.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                              '${flyerDocumentKinds[document.kind] ?? document.kind} · ${document.uploadedByName}',
                              style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 8),
                          if (document.isPdf) ...[
                            AppButton(
                                label: tr('View in app'),
                                kind: AppButtonKind.teal,
                                busy: _busy,
                                onPressed: () => _viewDocument(document)),
                            const SizedBox(height: 8),
                          ],
                          AppButton(
                              label: tr('Share'),
                              kind: AppButtonKind.quiet,
                              busy: _busy,
                              onPressed: () => _shareDocument(document)),
                          const SizedBox(height: 8),
                          AppButton(
                            label: document.verified
                                ? tr('Remove verification')
                                : tr('Mark verified'),
                            kind: document.verified
                                ? AppButtonKind.quiet
                                : AppButtonKind.teal,
                            onPressed: () =>
                                _verify(document, !document.verified),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}
