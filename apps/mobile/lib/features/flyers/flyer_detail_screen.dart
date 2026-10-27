import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/flyer.dart';
import '../../data/models/hub_flight.dart';
import '../../data/share_bytes.dart';
import '../../data/uploads/flutter_heic.dart';
import '../../data/uploads/photo_tray.dart';
import '../../data/uploads/photo_upload.dart';
import '../../data/uploads/quick_uploads.dart';
import '../../data/uploads/signed_photos.dart';
import '../../data/uploads/upload_queue.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/photo_parts.dart';
import '../../widgets/quick_parts.dart' show QueuedFilesCard;
import '../../widgets/remove_parts.dart';
import '../../widgets/team_parts.dart';
import '../../widgets/ui.dart';
import '../flights/flight_detail_screen.dart';
import '../pdf/pdf_bytes_screen.dart';
import 'flyers_screen.dart';

/// One flyer: profile, contact, documents to verify and their flights.
class FlyerDetailScreen extends StatefulWidget {
  const FlyerDetailScreen(
      {super.key, required this.name, this.uploads, this.pickFiles});

  final String name;

  /// Photos from the camera or gallery, or one PDF; tests pass their own.
  final Future<List<PickedPhoto>> Function(FileSource source)? pickFiles;

  /// Documents from the new flyer form that are still being sent or failed;
  /// a failed one can be sent again from here.
  final UploadQueue? uploads;

  @override
  State<FlyerDetailScreen> createState() => _FlyerDetailScreenState();
}

class _FlyerDetailScreenState extends State<FlyerDetailScreen> {
  FlyerDetail? _flyer;
  FlyerDocumentList? _documents;
  String? _error;
  var _loading = true;
  var _busy = false;
  var _archiving = false;
  var _deleting = false;
  var _kind = 'student_id';

  /// Photo documents wait here until Upload; they are stored as [_kind].
  PhotoTrayController? _tray;
  SignedPhotoLoader? _photos;

  var _uploadedSeen = 0;

  @override
  void initState() {
    super.initState();
    _uploadedSeen = widget.uploads?.doneCount ?? 0;
    widget.uploads?.addListener(_onUploads);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  /// Reloads the documents each time another queued file arrives.
  void _onUploads() {
    if (!mounted) return;
    final done = widget.uploads!.doneCount;
    if (done != _uploadedSeen) {
      _uploadedSeen = done;
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final flyers = AppScope.of(context).flyers;
    _photos ??= flyers.documentLoader(widget.name);
    _tray ??= PhotoTrayController(
        decodeHeic: flutterDecodeHeic,
        upload: (image, progress) => flyers.uploadDocument(
            name: widget.name, kind: _kind, image: image, onProgress: progress),
        onUploaded: _load)
      // The card's own Camera and Gallery wait while photos are sent.
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    widget.uploads?.removeListener(_onUploads);
    _tray?.dispose();
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

  /// Archiving asks first unless the operator already chose "Archive
  /// instead"; restoring does not ask.
  Future<void> _setArchived(bool archived, {bool confirm = true}) async {
    final flyer = _flyer;
    if (flyer == null) return;
    final flyers = AppScope.of(context).flyers;
    final done = await changeArchived(context,
        archived: archived,
        name: flyer.name,
        confirm: confirm,
        send: () => flyers.archive(flyer.name, archived: archived),
        onBusy: (busy) {
          if (mounted) setState(() => _archiving = busy);
        });
    if (done && mounted) await _load();
  }

  /// The server refuses while the flyer has flights, shipments, payments or
  /// stored documents; the refusal offers to archive instead.
  Future<void> _delete() async {
    final flyer = _flyer;
    if (flyer == null) return;
    final flyers = AppScope.of(context).flyers;
    await confirmAndDelete(context,
        title: tr('Delete flyer'),
        question: tr('Delete flyer {name}? This cannot be undone.',
            {'name': flyer.name}),
        refusedTitle: tr('This flyer cannot be deleted'),
        delete: () => flyers.delete(flyer.name),
        archiveInstead:
            flyer.archived ? null : () => _setArchived(true, confirm: false),
        onBusy: (busy) {
          if (mounted) setState(() => _deleting = busy);
        });
  }

  Future<void> _openFlight(String code) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FlightDetailScreen(code: code)));
    if (mounted) await _load();
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
    if (!document.isPdf) return _viewPhotos(document);
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

  /// Photo documents open in the viewer, swiping through every photo
  /// document of this flyer.
  Future<void> _viewPhotos(FlyerDocument document) {
    final photos = [
      for (final row in _documents?.documents ?? const <FlyerDocument>[])
        if (!row.isPdf) row
    ];
    return showPhotoViewer(context,
        photos: [
          for (final row in photos)
            ViewerPhoto.stored(row.reference,
                group: flyerDocumentKinds[row.kind] ?? row.kind)
        ],
        initial:
            photos.indexWhere((row) => row.reference == document.reference),
        loader: _photos);
  }

  Future<List<PickedPhoto>> _pickFiles(FileSource source) async {
    if (source != FileSource.pdf) return pickPhotos(source);
    final file = await pickDocument(source);
    return file == null ? const [] : [file];
  }

  /// A PDF is checked, confirmed by its name and then sent.
  Future<void> _pickPdf() async {
    final picked = await (widget.pickFiles ?? _pickFiles)(FileSource.pdf);
    if (!mounted || picked.isEmpty) return;
    final file = picked.single;
    final problem = pdfProblem(file);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final kind = flyerDocumentKinds[_kind] ?? _kind;
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              scrollable: true,
              title: Text(tr('Upload this PDF?')),
              content: Text('${file.name}\n$kind',
                  key: const Key('pdf-upload-name'),
                  style: const TextStyle(height: 1.5)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(tr('Cancel'))),
                FilledButton(
                    key: const Key('pdf-upload-confirm'),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(tr('Upload'))),
              ],
            ));
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).flyers.uploadPdf(
          name: widget.name,
          kind: _kind,
          filename: file.name,
          bytes: file.bytes,
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

  Future<void> _pick(FileSource source) async {
    final photos = await (widget.pickFiles ?? _pickFiles)(source);
    if (!mounted) return;
    await _tray?.add(photos);
  }

  @override
  Widget build(BuildContext context) {
    final flyer = _flyer;
    final documents = _documents;
    final pill = flyer == null
        ? null
        : flyer.archived
            ? StatusPill(label: tr('Archived'), tone: ChipTone.neutral)
            : docsVerified(flyer)
                ? StatusPill(label: tr('Docs verified'), tone: ChipTone.green)
                : StatusPill(label: tr('Docs pending'), tone: ChipTone.amber);
    return PhotoTrayGuard(
        tray: _tray,
        child: WorkspaceScaffold(
          title: tr('Flyer'),
          subtitle: tr('Profile, documents and flights'),
          root: false,
          onRefresh: _load,
          actions: [
            if (pill != null)
              Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(child: pill)),
          ],
          children: [
            if (_loading && flyer == null) const LinearProgressIndicator(),
            if (_error != null) ErrorNote(message: _error!, onRetry: _load),
            if (flyer != null) ...[
              if (flyer.archived) ...[
                ArchivedBanner(
                    archivedAt: flyer.archivedAt,
                    restoreLabel: tr('Restore flyer'),
                    busy: _archiving,
                    onRestore: () => _setArchived(false)),
                const SizedBox(height: 14),
              ],
              _ProfileCard(flyer: flyer),
              const SizedBox(height: 22),
              SectionTitle(title: tr('Contact')),
              _ContactGrid(flyer: flyer),
              const SizedBox(height: 22),
              SectionTitle(
                  title: tr('Documents'),
                  action: SectionCount(tr('{verified} of {total} verified', {
                    'verified': flyer.verifiedDocumentCount,
                    'total': flyer.documentCount
                  }))),
              if (widget.uploads case final uploads?)
                QueuedFilesCard(
                    queue: uploads,
                    titleOf: (kind) => flyerDocumentKinds[kind] ?? kind ?? ''),
              if (widget.uploads?.allDone == false) const SizedBox(height: 10),
              _documentsCard(documents),
              const SizedBox(height: 22),
              SectionTitle(
                  title: tr('Flights'),
                  action: SectionCount(
                      trn(flyer.flights.length, '{n} flight', '{n} flights'))),
              if (flyer.flights.isEmpty)
                EmptyNote(
                    icon: Icons.flight_outlined,
                    title: tr('No flights'),
                    body: tr('Flights appear here once created or assigned.'))
              else
                SurfaceGroup(children: [
                  for (final flight in flyer.flights)
                    _FlightRow(
                        flight: flight, onTap: () => _openFlight(flight.code)),
                ]),
              const SizedBox(height: 22),
              ProfileEndActions(
                  archived: flyer.archived,
                  archiveLabel: tr('Archive flyer'),
                  deleteLabel: tr('Delete flyer'),
                  archiving: _archiving,
                  deleting: _deleting,
                  onArchive: () => _setArchived(true),
                  onDelete: _delete),
            ],
          ],
        ));
  }

  Widget _documentsCard(FlyerDocumentList? documents) {
    final tray = _tray!;
    final off = documents?.configured == false;
    final rows = documents?.documents ?? const <FlyerDocument>[];
    return PaperCard(
        padding: EdgeInsets.zero,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (rows.isEmpty)
            Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const IconBadge(Icons.description_outlined,
                      tone: ChipTone.amber),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(tr('No documents yet'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(tr('Upload the student ID and visa to verify this flyer.'),
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.muted)),
                      ])),
                ]))
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.lineSoft),
              _DocumentRow(
                  document: rows[i],
                  busy: _busy,
                  onView: () => _viewDocument(rows[i]),
                  onShare: () => _shareDocument(rows[i]),
                  onVerify: (value) => _verify(rows[i], value)),
            ],
          Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: AppColors.lineSoft))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(tr('Add a document'),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkSoft))),
                      Text(tr('PDF up to 10 MB'),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ]),
                    const SizedBox(height: 10),
                    if (off) ...[
                      ErrorNote(
                          message: tr(
                              'Storage is not set up yet. Uploads are off until setup is complete.')),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: _kind,
                      isExpanded: true,
                      style: const TextStyle(
                          fontFamily: 'HindSiliguri',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink),
                      decoration: InputDecoration(
                          prefixIcon: fieldSign(tr('Type'), size: 13),
                          prefixIconConstraints: fieldSignConstraints,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12)),
                      items: [
                        for (final entry in flyerDocumentKinds.entries)
                          DropdownMenuItem(
                              value: entry.key, child: Text(entry.value))
                      ],
                      onChanged: off
                          ? null
                          : (value) => setState(() => _kind = value ?? _kind),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: SmallActionButton(
                              label: tr('Camera'),
                              icon: Icons.photo_camera_outlined,
                              onPressed: off || tray.uploading
                                  ? null
                                  : () => _pick(FileSource.camera))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: SmallActionButton(
                              label: tr('Gallery'),
                              icon: Icons.image_outlined,
                              onPressed: off || tray.uploading
                                  ? null
                                  : () => _pick(FileSource.gallery))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: SmallActionButton(
                              label: 'PDF',
                              icon: Icons.upload_rounded,
                              tonal: true,
                              busy: _busy,
                              onPressed: off ? null : _pickPdf)),
                    ]),
                    PhotoTray(
                        tray: tray,
                        onPick: _pick,
                        enabled: !off,
                        showPickers: false,
                        group: flyerDocumentKinds[_kind] ?? _kind),
                  ])),
        ]));
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.flyer});
  final FlyerDetail flyer;

  @override
  Widget build(BuildContext context) {
    final study = [
      if (flyer.program.isNotEmpty) flyer.program,
      if (flyer.batch.isNotEmpty) tr('Batch {batch}', {'batch': flyer.batch}),
    ].join(' · ');
    Widget stat(String label, String value) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      fontFeatures: [FontFeature.tabularFigures()]))),
        ]);
    return PaperCard(
        radius: heroRadius,
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            InitialsAvatar(flyer.name,
                size: 56,
                tone: flyer.archived ? AvatarTone.muted : AvatarTone.filled),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(flyer.name,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.25)),
                  if (flyer.university.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.school_outlined,
                          size: 16, color: AppColors.inkSoft),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(flyer.university,
                              style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: AppColors.inkSoft))),
                    ]),
                  if (study.isNotEmpty)
                    Text(study,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                ])),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.lineSoft),
          const SizedBox(height: 14),
          IntrinsicHeight(
              child: Row(children: [
            Expanded(child: stat(tr('Flights'), '${flyer.flights.length}')),
            const VerticalDivider(width: 16, color: AppColors.lineSoft),
            Expanded(
                child: stat(tr('Total booked'),
                    '${flyer.totalKg.toStringAsFixed(1)} kg')),
            const VerticalDivider(width: 16, color: AppColors.lineSoft),
            Expanded(
                child: stat(tr('Documents'),
                    '${flyer.verifiedDocumentCount} / ${flyer.documentCount}')),
          ])),
        ]));
  }
}

class _ContactGrid extends StatelessWidget {
  const _ContactGrid({required this.flyer});
  final FlyerDetail flyer;

  @override
  Widget build(BuildContext context) {
    const valueStyle =
        TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);
    Widget cell(IconData icon, String label, String value,
            {bool phone = false}) =>
        Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted))),
              ]),
              const SizedBox(height: 2),
              if (phone)
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(value.trim().isEmpty ? '—' : value,
                        maxLines: 1, style: valueStyle))
              else
                Text(value.trim().isEmpty ? '—' : value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle),
            ]));
    Widget pair(Widget a, Widget b) => IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: a),
          const VerticalDivider(width: 1, color: AppColors.lineSoft),
          Expanded(child: b),
        ]));
    return PaperCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          pair(
              cell(Icons.phone_outlined, tr('BD phone'), flyer.bdPhone,
                  phone: true),
              cell(Icons.phone_outlined, tr('CN phone'), flyer.cnPhone,
                  phone: true)),
          const Divider(height: 1, color: AppColors.lineSoft),
          pair(
              cell(Icons.chat_bubble_outline_rounded, 'WeChat', flyer.wechat),
              cell(Icons.person_outline_rounded, tr('Emergency'),
                  flyer.emergencyContact)),
        ]));
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow(
      {required this.document,
      required this.busy,
      required this.onView,
      required this.onShare,
      required this.onVerify});
  final FlyerDocument document;
  final bool busy;
  final VoidCallback onView, onShare;
  final ValueChanged<bool> onVerify;

  @override
  Widget build(BuildContext context) {
    final verified = document.verified;
    final kind = flyerDocumentKinds[document.kind] ?? document.kind;
    final by = document.verifiedByName;
    return Padding(
        padding: EdgeInsets.fromLTRB(14, 12, 6, verified ? 2 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBadge(
                document.isPdf
                    ? Icons.description_outlined
                    : Icons.image_outlined,
                tone: verified ? ChipTone.neutral : ChipTone.amber),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(document.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(
                      document.uploadedByName.isEmpty
                          ? kind
                          : tr('{kind} · by {name}',
                              {'kind': kind, 'name': document.uploadedByName}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                ])),
            IconButton(
                key: ValueKey('document-view-${document.reference}'),
                tooltip: tr('View in app'),
                color: AppColors.primary,
                onPressed: busy ? null : onView,
                icon: const Icon(Icons.visibility_outlined, size: 20)),
            IconButton(
                tooltip: tr('Share'),
                color: AppColors.primary,
                onPressed: busy ? null : onShare,
                icon: const Icon(Icons.share_outlined, size: 20)),
          ]),
          if (verified)
            Padding(
                padding: const EdgeInsetsDirectional.only(start: 52),
                child: Row(children: [
                  Expanded(
                      child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TickPill(
                              label: by == null || by.isEmpty
                                  ? tr('Verified')
                                  : tr('Verified by {name}', {'name': by})))),
                  const SizedBox(width: 4),
                  TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                              fontFamily: 'HindSiliguri',
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      onPressed: () => onVerify(false),
                      child: Text(tr('Remove verification'))),
                ]))
          else
            Padding(
                padding: const EdgeInsetsDirectional.only(
                    start: 52, top: 10, end: 8),
                child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.accentSoft,
                            foregroundColor: AppColors.accentInk,
                            minimumSize: const Size(48, 44),
                            side: const BorderSide(
                                color: AppColors.accentLine, width: 1.5),
                            textStyle: const TextStyle(
                                fontFamily: 'HindSiliguri',
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        onPressed: () => onVerify(true),
                        icon: const Icon(Icons.check_rounded, size: 17),
                        label: Text(tr('Mark verified'))))),
        ]));
  }
}

class _FlightRow extends StatelessWidget {
  const _FlightRow({required this.flight, required this.onTap});
  final FlyerFlight flight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final upcoming = flight.status == 'upcoming';
    final day = FlightDay.parse(flight.date);
    final when = [
      day == null ? flight.date : '${day.day} ${day.month}',
      if (flight.depTime.isNotEmpty || flight.arrTime.isNotEmpty)
        '${flight.depTime}–${flight.arrTime}',
    ].join(' · ');
    final (label, tone) = switch (flight.status) {
      'upcoming' => (tr('Upcoming'), ChipTone.blue),
      'departed' => (tr('Departed'), ChipTone.amber),
      'completed' => (tr('Completed'), ChipTone.green),
      _ => (flight.statusLabel, ChipTone.neutral),
    };
    final share =
        flight.spaceKg <= 0 ? 0.0 : (flight.bookedKg / flight.spaceKg);
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              IconBadge(Icons.flight_rounded,
                  tone: upcoming ? ChipTone.blue : ChipTone.neutral),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Flexible(
                          child: Text(displayFlightCode(flight.code),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      StatusPill(label: label, tone: tone),
                    ]),
                    Text(when,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                  value: share.clamp(0.0, 1.0),
                                  minHeight: 6,
                                  color: share > 1
                                      ? AppColors.danger
                                      : upcoming
                                          ? AppColors.primary
                                          : AppColors.ok,
                                  backgroundColor: AppColors.lineSoft))),
                      const SizedBox(width: 8),
                      Text(
                          '${flight.bookedKg.toStringAsFixed(1)} / ${flight.spaceKg} kg',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSoft)),
                    ]),
                  ])),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.faint),
            ])));
  }
}
