import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/uploads/flutter_heic.dart';
import '../../data/uploads/photo_tray.dart';
import '../../data/uploads/photo_upload.dart';
import '../../data/uploads/quick_uploads.dart';
import '../../data/uploads/signed_photos.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/photo_parts.dart';
import '../../widgets/round7_parts.dart' show CardHead;
import '../../widgets/ui.dart';

class DeviceUnitRef {
  const DeviceUnitRef(
      {required this.itemIndex,
      required this.unitIndex,
      required this.category,
      required this.model,
      required this.serial,
      required this.hasPhoto,
      this.photoRef});

  final int itemIndex;
  final int unitIndex;
  final String category;
  final String model;
  final String serial;
  final bool hasPhoto;

  /// The stored serial photo, when the server sends its reference.
  final String? photoRef;
}

class DeviceUnitsScreen extends StatefulWidget {
  const DeviceUnitsScreen({super.key, required this.code, required this.hub});

  final String code;
  final bool hub;

  @override
  State<DeviceUnitsScreen> createState() => _DeviceUnitsScreenState();
}

class _DeviceUnitsScreenState extends State<DeviceUnitsScreen> {
  List<DeviceUnitRef> _units = const [];
  String? _error;
  var _loading = true;

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
      final shipments = AppScope.of(context).shipments;
      final units = <DeviceUnitRef>[];
      if (widget.hub) {
        final detail = await shipments.hubDetail(widget.code);
        for (var item = 0; item < detail.devices.length; item++) {
          final line = detail.devices[item];
          for (var unit = 0; unit < line.units.length; unit++) {
            final row = line.units[unit];
            units.add(DeviceUnitRef(
                itemIndex: item,
                unitIndex: unit,
                category: line.category,
                model: row.model,
                serial: row.serial,
                hasPhoto: row.hasPhoto,
                photoRef: row.serialPhotoRef));
          }
        }
      } else {
        final detail = await shipments.adminDetail(widget.code);
        for (var item = 0; item < detail.devices.length; item++) {
          final line = detail.devices[item];
          for (var unit = 0; unit < line.units.length; unit++) {
            final row = line.units[unit];
            units.add(DeviceUnitRef(
                itemIndex: item,
                unitIndex: unit,
                category: line.category,
                model: row.model,
                serial: row.serial,
                hasPhoto: row.serialPhotoRef != null &&
                    row.serialPhotoRef!.isNotEmpty,
                photoRef: row.serialPhotoRef));
          }
        }
      }
      if (!mounted) return;
      setState(() => _units = units);
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
    return WorkspaceScaffold(
        title: tr('IMEI photos'),
        root: false,
        onRefresh: _load,
        subtitle: widget.code,
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'Each device has its own serial photo. It is not shared with the customer.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && _units.isEmpty)
            EmptyNote(
                title: tr('No devices'),
                body: tr(
                    'Units appear here when intake includes mobiles, laptops or drones.')),
          for (final unit in _units) ...[
            DirectoryTile(
              title: unit.model.isEmpty ? unit.category : unit.model,
              subtitle:
                  unit.serial.isEmpty ? tr('No serial recorded') : unit.serial,
              badge: unit.hasPhoto ? tr('Has photo') : tr('No photo'),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        ImeiGuideScreen(code: widget.code, unit: unit)));
                await _load();
              },
            ),
            const SizedBox(height: 8),
          ],
        ]);
  }
}

class ImeiGuideScreen extends StatefulWidget {
  const ImeiGuideScreen(
      {super.key, required this.code, required this.unit, this.pickPhotos});

  final String code;
  final DeviceUnitRef unit;

  /// Camera or gallery, one photo; tests pass their own.
  final Future<List<PickedPhoto>> Function(FileSource source)? pickPhotos;

  @override
  State<ImeiGuideScreen> createState() => _ImeiGuideScreenState();
}

class _ImeiGuideScreenState extends State<ImeiGuideScreen> {
  /// The picked photo waits here until Upload.
  PhotoTrayController? _tray;
  SignedPhotoLoader? _photos;
  String? _saved;

  /// The serial photo on the server: the unit's, then the one sent here.
  late String? _photoRef = widget.unit.photoRef;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = AppScope.of(context).media;
    _photos ??= media.photoLoader(widget.code);
    _tray ??= PhotoTrayController(
        decodeHeic: flutterDecodeHeic,
        single: true,
        upload: (image, progress) async {
          final reference = await media.uploadDevicePhoto(
            code: widget.code,
            itemIndex: widget.unit.itemIndex,
            unitIndex: widget.unit.unitIndex,
            image: image,
            onProgress: progress,
          );
          if (reference.isNotEmpty) _photoRef = reference;
        },
        onUploaded: () {
          if (!mounted) return;
          setState(
              () => _saved = tr('Photo saved. The customer cannot see it.'));
        });
  }

  @override
  void dispose() {
    _tray?.dispose();
    _photos?.dispose();
    super.dispose();
  }

  /// One photo: the camera's, or one from the gallery.
  Future<List<PickedPhoto>> _pickOne(FileSource source) async {
    if (source == FileSource.camera) return pickPhotos(source);
    final photo = await pickDocument(source);
    return photo == null ? const [] : [photo];
  }

  Future<void> _pick(FileSource source) async {
    final photos = await (widget.pickPhotos ?? _pickOne)(source);
    if (!mounted || photos.isEmpty) return;
    setState(() => _saved = null);
    await _tray?.add(photos);
  }

  void _open(String reference) {
    showPhotoViewer(context,
        photos: [ViewerPhoto.stored(reference, group: _label)],
        loader: _photos);
  }

  String get _label {
    final unit = widget.unit;
    final name = unit.model.isEmpty ? unit.category : unit.model;
    return unit.serial.isEmpty ? name : '$name · ${unit.serial}';
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final stored = _photoRef;
    return PhotoTrayGuard(
        tray: _tray,
        child: WorkspaceScaffold(
            title: unit.serial.isEmpty ? unit.category : unit.serial,
            root: false,
            children: [
              Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                      '${widget.code} · ${unit.model.isEmpty ? unit.category : unit.model}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted, height: 1.5))),
              if (stored != null && stored.isNotEmpty) ...[
                PaperCard(
                    key: const Key('imei-current'),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CardHead(
                              title: tr('Current photo'),
                              subtitle:
                                  tr('Uploading a new photo replaces it.')),
                          const SizedBox(height: 12),
                          AspectRatio(
                              aspectRatio: 4 / 3,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: StoredPhotoImage(
                                      key: ValueKey('imei-photo-$stored'),
                                      loader: _photos!,
                                      reference: stored,
                                      cacheWidth: 900,
                                      onTap: () => _open(stored)))),
                        ])),
                const SizedBox(height: 12),
              ] else ...[
                const _GuideFrame(),
                const SizedBox(height: 12),
              ],
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('1. Dial *#06#, or open the label on the box.')),
                    const SizedBox(height: 6),
                    Text(tr(
                        '2. Keep the number inside the frame. Avoid direct light.')),
                    const SizedBox(height: 6),
                    Text(tr(
                        '3. The photo is saved as JPEG, its location is removed, and it stays out of customer links.')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PaperCard(
                  child: PhotoTray(
                      tray: _tray!, onPick: _pick, group: tr('IMEI photos'))),
              if (_saved != null) ...[
                const SizedBox(height: 12),
                EmptyNote(title: tr('Saved'), body: _saved!),
              ],
            ]));
  }
}

class _GuideFrame extends StatelessWidget {
  const _GuideFrame();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(cardRadius)),
        child: CustomPaint(
          painter: _FramePainter(),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Text(
                'IMEI\n${tr('here')}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const length = 28.0;
    const inset = 22.0;
    void corner(Offset start, Offset turn, Offset end) {
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(turn.dx, turn.dy)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, paint);
    }

    corner(const Offset(inset, inset + length), const Offset(inset, inset),
        const Offset(inset + length, inset));
    corner(
        Offset(size.width - inset - length, inset),
        Offset(size.width - inset, inset),
        Offset(size.width - inset, inset + length));
    corner(
        Offset(inset, size.height - inset - length),
        Offset(inset, size.height - inset),
        Offset(inset + length, size.height - inset));
    corner(
        Offset(size.width - inset, size.height - inset - length),
        Offset(size.width - inset, size.height - inset),
        Offset(size.width - inset - length, size.height - inset));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
