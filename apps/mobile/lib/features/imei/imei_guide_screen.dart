import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/uploads/flutter_heic.dart';
import '../../data/uploads/image_prepare.dart';
import '../../data/uploads/picked_photo_file.dart';
import '../../data/uploads/photo_upload.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';

class DeviceUnitRef {
  const DeviceUnitRef(
      {required this.itemIndex,
      required this.unitIndex,
      required this.category,
      required this.model,
      required this.serial,
      required this.hasPhoto});

  final int itemIndex;
  final int unitIndex;
  final String category;
  final String model;
  final String serial;
  final bool hasPhoto;
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
                hasPhoto: row.hasPhoto));
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
                    row.serialPhotoRef!.isNotEmpty));
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
        title: 'IMEI ছবি',
        root: false,
        onRefresh: _load,
        subtitle: widget.code,
        children: [
          const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                  'প্রতিটি ডিভাইসের সিরিয়াল ছবি আলাদা। কাস্টমারের সাথে শেয়ার হয় না।',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && _units.isEmpty)
            const EmptyNote(
                title: 'ডিভাইস নেই',
                body: 'ইনটেকে মোবাইল, ল্যাপটপ বা ড্রোন দিলে এখানে ইউনিট আসবে।'),
          for (final unit in _units) ...[
            DirectoryTile(
              title: unit.model.isEmpty ? unit.category : unit.model,
              subtitle: unit.serial.isEmpty ? 'সিরিয়াল লেখা নেই' : unit.serial,
              badge: unit.hasPhoto ? 'ছবি আছে' : 'ছবি নেই',
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
  const ImeiGuideScreen({super.key, required this.code, required this.unit});

  final String code;
  final DeviceUnitRef unit;

  @override
  State<ImeiGuideScreen> createState() => _ImeiGuideScreenState();
}

class _ImeiGuideScreenState extends State<ImeiGuideScreen> {
  PhotoUploadController? _photos;
  String? _saved;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _photos ??= PhotoUploadController(
      decodeHeic: flutterDecodeHeic,
      upload: (image, progress) {
        return AppScope.of(context).media.uploadDevicePhoto(
              code: widget.code,
              itemIndex: widget.unit.itemIndex,
              unitIndex: widget.unit.unitIndex,
              image: image,
              onProgress: progress,
            );
      },
    )..addListener(() {
        if (!mounted) return;
        setState(() {
          if (_photos?.done == true) {
            _saved = 'ছবি সেভ হয়েছে। কাস্টমার এটি দেখতে পাবে না।';
          }
        });
      });
  }

  @override
  void dispose() {
    _photos?.dispose();
    super.dispose();
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
    final upload = _photos;
    final unit = widget.unit;
    return WorkspaceScaffold(
        title: unit.serial.isEmpty ? unit.category : unit.serial,
        root: false,
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  '${widget.code} · ${unit.model.isEmpty ? unit.category : unit.model}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          const _GuideFrame(),
          const SizedBox(height: 12),
          const PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('১. ডায়ালারে *#06# চাপুন, অথবা বক্সের লেবেল খুলুন।'),
                SizedBox(height: 6),
                Text('২. নম্বরটা ফ্রেমের ভিতরে রাখুন। সরাসরি আলো এড়ান।'),
                SizedBox(height: 6),
                Text(
                    '৩. ছবি JPEG হবে, লোকেশন মুছে যাবে, এবং কাস্টমার লিংকে যাবে না।'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: AppButton(
                      label: 'ক্যামেরা',
                      kind: AppButtonKind.current,
                      onPressed: () => _pick(ImageSource.camera))),
              const SizedBox(width: 8),
              Expanded(
                  child: AppButton(
                      label: 'গ্যালারি',
                      kind: AppButtonKind.quiet,
                      onPressed: () => _pick(ImageSource.gallery))),
            ],
          ),
          if (upload != null && upload.busy) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
                value: upload.progress == 0 ? null : upload.progress,
                color: AppColors.teal,
                backgroundColor: AppColors.tealSoft),
          ],
          if (upload?.prepared != null) ...[
            const SizedBox(height: 8),
            const Text(locationStrippedNote,
                style: TextStyle(color: AppColors.muted)),
          ],
          if (upload?.error != null) ...[
            const SizedBox(height: 8),
            Text(upload!.error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
            const SizedBox(height: 8),
            AppButton(label: 'একই ছবি আবার পাঠান', onPressed: upload.retry),
          ],
          if (_saved != null) ...[
            const SizedBox(height: 12),
            EmptyNote(title: 'সেভ হয়েছে', body: _saved!),
          ],
        ]);
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
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(36),
              child: Text(
                'IMEI\nএখানে',
                textAlign: TextAlign.center,
                style: TextStyle(
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
