import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flyer.dart';
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
        if (query.isEmpty || row.name.toLowerCase().contains(query) || row.bdPhone.toLowerCase().contains(query) || row.university.toLowerCase().contains(query)) row,
    ];
    return Scaffold(
      appBar: const BackTitle(title: 'ফ্লায়ার'),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 28),
          children: [
            const PageHeader(title: 'ফ্লায়ার', subtitle: 'প্রোফাইল, ফোন ও যাচাই করা ডকুমেন্ট।'),
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'নাম, ফোন বা বিশ্ববিদ্যালয়'),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'নতুন ফ্লায়ার',
              kind: AppButtonKind.current,
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const FlyerFormScreen()));
                if (created == true) await _load();
              },
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
            if (_error != null) ErrorNote(message: _error!, onRetry: _load),
            if (!_loading && _error == null && visible.isEmpty) const EmptyNote(title: 'ফ্লায়ার নেই', body: 'নতুন প্রোফাইল যোগ করলে এখানে দেখা যাবে।'),
            for (final row in visible) ...[
              DirectoryTile(
                title: row.name,
                subtitle: '${row.bdPhone} · ${row.university}\nডকুমেন্ট ${row.verifiedDocumentCount}/${row.documentCount} যাচাই',
                badge: row.docStudentId && row.docVisa ? 'যাচাই' : 'বাকি',
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FlyerDetailScreen(name: row.name)));
                  await _load();
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
