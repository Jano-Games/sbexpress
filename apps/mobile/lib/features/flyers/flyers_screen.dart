import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flyer.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart' show localTime, shortDate;
import '../../widgets/remove_parts.dart';
import '../../widgets/team_parts.dart';
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

  /// Active and archived flyers together; the tabs split them.
  List<FlyerSummary> _rows = const [];
  String? _error;
  var _loading = true;
  var _loaded = false;
  var _tab = 0;

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
      final rows =
          await AppScope.of(context).flyers.list(includeArchived: true);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loaded = true;
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

  Future<void> _create() async {
    final created = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const FlyerFormScreen()));
    if (created == true && mounted) await _load();
  }

  Future<void> _open(FlyerSummary row) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FlyerDetailScreen(name: row.name)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final archivedTab = _tab == 1;
    final activeRows = [
      for (final row in _rows)
        if (!row.archived) row
    ];
    final archivedRows = [
      for (final row in _rows)
        if (row.archived) row
    ];
    final rows = archivedTab ? archivedRows : activeRows;
    final query = _query.text.trim().toLowerCase();
    final visible = [
      for (final row in rows)
        if (query.isEmpty ||
            row.name.toLowerCase().contains(query) ||
            row.bdPhone.toLowerCase().contains(query) ||
            row.cnPhone.toLowerCase().contains(query) ||
            row.university.toLowerCase().contains(query))
          row,
    ];
    final active = activeRows.length;
    final pending = activeRows.where((row) => !docsVerified(row));
    return WorkspaceScaffold(
        title: tr('Flyers'),
        subtitle: tr('Profiles and travel documents'),
        root: false,
        onRefresh: _load,
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 12),
              child: BarPillButton(label: tr('New'), onPressed: _create)),
        ],
        toolbar: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                    hintText: tr('Search name, phone or university'),
                    fillColor: AppColors.paper,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2)),
                    prefixIcon: const Icon(Icons.search_rounded)),
              ),
              const SizedBox(height: 10),
              ScreenTabs(
                  key: const Key('flyers-tabs'),
                  labels: activeArchivedLabels(
                      active: _loaded ? activeRows.length : null,
                      archived: _loaded ? archivedRows.length : null),
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i)),
            ]),
        children: [
          if (_loading && _rows.isEmpty) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!archivedTab && activeRows.isNotEmpty) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: _SummaryTile(
                      icon: Icons.badge_outlined,
                      value: active,
                      label: tr('Active flyers'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _SummaryTile(
                      icon: Icons.assignment_late_outlined,
                      value: pending.length,
                      label: tr('Docs pending'),
                      hot: pending.isNotEmpty)),
            ]),
            const SizedBox(height: 18),
          ],
          if (!_loading && _error == null && rows.isEmpty)
            archivedTab
                ? EmptyNote(
                    icon: Icons.archive_outlined,
                    title: tr('No archived flyers'),
                    body: tr(
                        'Flyers you archive appear here. Their history stays.'))
                : EmptyNote(
                    icon: Icons.badge_outlined,
                    title: tr('No flyers'),
                    body: tr('New profiles will appear here.'))
          else if (rows.isNotEmpty) ...[
            SectionTitle(
                title: archivedTab ? tr('Archived flyers') : tr('All flyers'),
                action: SectionCount(
                    trn(visible.length, '{n} profile', '{n} profiles'))),
            if (visible.isEmpty)
              EmptyNote(
                  icon: Icons.search_off_rounded,
                  title: tr('No flyers match'),
                  body: tr('Try another name, phone or university.'))
            else
              SurfaceGroup(children: [
                for (final row in visible)
                  _FlyerRow(row: row, onTap: () => _open(row)),
              ]),
            if (!archivedTab) ...[
              const SizedBox(height: 14),
              TipNote(
                  text: tr(
                      'A flyer counts as verified once the student ID and visa are both checked. Open a profile to verify files.')),
            ],
          ],
        ]);
  }
}

/// The two papers a flyer needs before travelling: student ID and visa.
bool docsVerified(FlyerSummary row) => row.docStudentId && row.docVisa;

/// What still blocks a flyer, written after the verified count.
String flyerDocProgress(FlyerSummary row) {
  final args = {
    'verified': row.verifiedDocumentCount,
    'total': row.documentCount
  };
  if (docsVerified(row)) {
    return tr('{verified} of {total} documents verified', args);
  }
  if (!row.docStudentId && !row.docVisa) {
    return tr('{verified} of {total} verified · ID and visa waiting', args);
  }
  return row.docVisa
      ? tr('{verified} of {total} verified · student ID waiting', args)
      : tr('{verified} of {total} verified · visa waiting', args);
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile(
      {required this.icon,
      required this.value,
      required this.label,
      this.hot = false});
  final IconData icon;
  final int value;
  final String label;
  final bool hot;

  @override
  Widget build(BuildContext context) => PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 14,
      border: hot
          ? const BorderSide(color: AppColors.accentLine, width: 1.5)
          : null,
      child: Row(children: [
        IconBadge(icon, tone: hot ? ChipTone.amber : ChipTone.blue, size: 40),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, height: 1.15)),
          WordFitText(label,
              maxLines: 2,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: hot ? AppColors.accentInk : AppColors.inkSoft)),
        ])),
      ]));
}

class _FlyerRow extends StatelessWidget {
  const _FlyerRow({required this.row, required this.onTap});
  final FlyerSummary row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final verified = docsVerified(row);
    final archivedOn =
        row.archivedAt == null ? null : localTime(row.archivedAt!);
    final detail = [
      if (row.bdPhone.isNotEmpty) row.bdPhone,
      if (row.university.isNotEmpty) row.university,
    ].join(' · ');
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              InitialsAvatar(row.name,
                  tone: row.archived || row.documentCount == 0
                      ? AvatarTone.muted
                      : AvatarTone.soft),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    LayoutBuilder(
                        builder: (context, box) => Row(children: [
                              Expanded(
                                  child: Text(row.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: row.archived
                                              ? AppColors.inkSoft
                                              : AppColors.ink))),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxWidth: box.maxWidth * 0.48),
                                  child: row.archived
                                      ? StatusPill(
                                          label: tr('Archived'),
                                          tone: ChipTone.neutral)
                                      : StatusPill(
                                          label: verified
                                              ? tr('Docs verified')
                                              : tr('Docs pending'),
                                          tone: verified
                                              ? ChipTone.green
                                              : ChipTone.amber)),
                            ])),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                    ],
                    const SizedBox(height: 6),
                    if (row.archived)
                      Row(children: [
                        const Icon(Icons.archive_outlined,
                            size: 15, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                archivedOn == null
                                    ? tr('Archived')
                                    : tr('Archived {date}',
                                        {'date': shortDate(archivedOn)}),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted))),
                      ])
                    else if (row.documentCount == 0)
                      Row(children: [
                        const Icon(Icons.upload_rounded,
                            size: 15, color: AppColors.accentInk),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(tr('No documents uploaded yet'),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accentInk))),
                      ])
                    else
                      Row(children: [
                        ExcludeSemantics(
                            child: StepBars(
                                done: row.verifiedDocumentCount
                                    .clamp(0, row.documentCount.clamp(1, 6)),
                                total: row.documentCount.clamp(1, 6),
                                current: !verified,
                                segmentWidth: 18,
                                height: 5)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(flyerDocProgress(row),
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: AppColors.muted))),
                      ]),
                  ])),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.faint),
            ])));
  }
}
