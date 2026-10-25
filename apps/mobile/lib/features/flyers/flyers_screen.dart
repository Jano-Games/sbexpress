import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flyer.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import 'flyer_detail_screen.dart';
import 'flyer_form_screen.dart';

class FlyersScreen extends StatefulWidget {
  const FlyersScreen({super.key});

  @override
  State<FlyersScreen> createState() => _FlyersScreenState();
}

class _FlyersScreenState extends State<FlyersScreen> {
  final _query = TextEditingController();
  List<FlyerSummary> _rows = const [];
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await AppScope.of(context).flyers.list();
      if (!mounted) return;
      setState(() => _rows = rows);
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
    final query = _query.text.trim().toLowerCase();
    final visible = [
      for (final row in _rows)
        if (query.isEmpty ||
            row.name.toLowerCase().contains(query) ||
            row.bdPhone.toLowerCase().contains(query) ||
            row.university.toLowerCase().contains(query))
          row,
    ];
    return WorkspaceScaffold(
        title: tr('Flyers'),
        root: false,
        onRefresh: _load,
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AppButton(
                  label: tr('New'),
                  icon: Icons.add_rounded,
                  expand: false,
                  onPressed: () async {
                    final created = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                            builder: (_) => const FlyerFormScreen()));
                    if (created == true && mounted) await _load();
                  }))
        ],
        toolbar: TextField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
              hintText: tr('Search name or phone'),
              prefixIcon: const Icon(Icons.search_rounded)),
        ),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(tr('Profiles and travel documents'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && _error == null && visible.isEmpty)
            EmptyNote(
                title: tr('No flyers'),
                body: tr('New profiles will appear here.')),
          for (final row in visible) ...[
            DirectoryTile(
              title: row.name,
              icon: Icons.badge_outlined,
              subtitle: [
                '${row.bdPhone} · ${row.university}',
                tr('{verified}/{total} documents verified', {
                  'verified': row.verifiedDocumentCount,
                  'total': row.documentCount
                })
              ].join('\n'),
              badge: row.docStudentId && row.docVisa
                  ? tr('Docs verified')
                  : tr('Docs pending'),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => FlyerDetailScreen(name: row.name)));
                await _load();
              },
            ),
            const SizedBox(height: 8),
          ],
        ]);
  }
}
