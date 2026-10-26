import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/workspace.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/team_parts.dart';
import '../../widgets/ui.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<StaffAccount> _staff = const [];
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
      final staff = await AppScope.of(context).settings.staff();
      if (!mounted) return;
      setState(() => _staff = staff);
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

  Future<void> _edit(StaffAccount person, String? self) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => StaffEditScreen(person: person, selfId: self)));
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final self = AppScope.of(context).session.user?.id;
    final admins = [
      for (final person in _staff)
        if (person.role != 'hub') person
    ];
    final hub = [
      for (final person in _staff)
        if (person.role == 'hub') person
    ];
    final active = _staff.where((person) => person.active).length;
    Widget group(String title, List<StaffAccount> people) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle(title: title, action: SectionCount('${people.length}')),
          SurfaceGroup(children: [
            for (final person in people)
              _PersonRow(
                  person: person,
                  self: person.id == self,
                  onTap: () => _edit(person, self)),
          ]),
          const SizedBox(height: 20),
        ]);
    return WorkspaceScaffold(
        title: tr('Staff'),
        subtitle: tr('Access and passwords'),
        root: false,
        onRefresh: _load,
        actions: [
          if (_staff.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                    child: StatusPill(
                        label: tr('{n} active', {'n': active}),
                        tone: ChipTone.green))),
        ],
        footer: ActionFooter(
            child: AppButton(
          label: tr('New staff'),
          icon: Icons.person_add_alt_1_outlined,
          kind: AppButtonKind.current,
          onPressed: () async {
            final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const StaffCreateScreen()));
            if (changed == true && mounted) await _load();
          },
        )),
        children: [
          const _RoleCards(),
          const SizedBox(height: 20),
          if (_loading && _staff.isEmpty) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (admins.isNotEmpty) group(tr('Admins'), admins),
          if (hub.isNotEmpty) group(tr('Hub'), hub),
          TipNote(
              icon: Icons.key_outlined,
              text: tr(
                  'Open a person to change their role, switch them off or set a new password. Another admin has to change your own role.')),
        ]);
  }
}

/// What each role can see, so the choice is clear before editing.
class _RoleCards extends StatelessWidget {
  const _RoleCards();

  @override
  Widget build(BuildContext context) {
    Widget card(IconData icon, ChipTone tone, String title, String body) =>
        PaperCard(
            radius: 14,
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconBadge(icon, tone: tone, size: 32),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 6),
              Text(body,
                  style: const TextStyle(
                      fontSize: 13, height: 1.45, color: AppColors.muted)),
            ]));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child: card(Icons.shield_outlined, ChipTone.blue, tr('Admin'),
              tr('Sees everything, including money'))),
      const SizedBox(width: 10),
      Expanded(
          child: card(Icons.inventory_2_outlined, ChipTone.neutral, tr('Hub'),
              tr('Handles shipments. No money or customer names'))),
    ]);
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow(
      {required this.person, required this.self, required this.onTap});
  final StaffAccount person;
  final bool self;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            InitialsAvatar(person.name,
                letters: 1,
                tone: self
                    ? AvatarTone.filled
                    : person.active
                        ? AvatarTone.soft
                        : AvatarTone.muted),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Flexible(
                        child: Text(person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: person.active
                                    ? AppColors.ink
                                    : AppColors.inkSoft))),
                    if (self) ...[
                      const SizedBox(width: 8),
                      StatusPill(label: tr('You'), tone: ChipTone.blue),
                    ],
                  ]),
                  Text(
                      person.active
                          ? person.email
                          : '${person.email} · ${tr("can't sign in")}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                ])),
            const SizedBox(width: 8),
            StatusPill(
                label: person.active ? tr('Active') : tr('Inactive'),
                tone: person.active ? ChipTone.green : ChipTone.neutral),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.faint),
          ])));
}

List<SegmentOption<String>> _roleOptions() => [
      (value: 'admin', label: tr('Admin'), icon: Icons.shield_outlined),
      (value: 'hub', label: tr('Hub'), icon: Icons.inventory_2_outlined),
    ];

String _roleNote(String role) => role == 'hub'
    ? tr('Handles shipments. No money or customer names')
    : tr('Sees everything, including money');

class StaffCreateScreen extends StatefulWidget {
  const StaffCreateScreen({super.key});

  @override
  State<StaffCreateScreen> createState() => _StaffCreateScreenState();
}

class _StaffCreateScreenState extends State<StaffCreateScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _role = 'hub';
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final password = _password.text;
    if (name.isEmpty ||
        !email.contains('@') ||
        password.length < 8 ||
        password.length > 128) {
      setState(() => _error =
          tr('Enter a name, email and a password of 8–128 characters.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).settings.createStaff(
          name: name, email: email, role: _role, password: password);
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
    return WorkspaceScaffold(
        title: tr('New staff'),
        subtitle: tr('Access and passwords'),
        root: false,
        footer: FooterActions(
            error: _error,
            child: AppButton(
                label: tr('Create staff'),
                icon: Icons.person_add_alt_1_outlined,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          FormCard(title: tr('Profile'), children: [
            LabeledField(
                label: tr('Name'),
                child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next)),
            LabeledField(
                label: tr('Email'),
                child: TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next)),
            LabeledField(
                label: tr('Password'),
                helper: tr('8–128 characters'),
                child: TextField(
                    controller: _password,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false)),
          ]),
          const SizedBox(height: 14),
          FormCard(title: tr('Role'), gap: 10, children: [
            SegmentPicker<String>(
                options: _roleOptions(),
                selected: _role,
                onChanged: (value) => setState(() => _role = value)),
            Text(_roleNote(_role),
                style: const TextStyle(
                    fontSize: 13, height: 1.45, color: AppColors.muted)),
          ]),
          const SizedBox(height: 14),
          TipNote(
              text: tr(
                  'Hub managers handle shipments. Money is handled by admins.')),
        ]);
  }
}

class StaffEditScreen extends StatefulWidget {
  const StaffEditScreen(
      {super.key, required this.person, required this.selfId});

  final StaffAccount person;
  final String? selfId;

  @override
  State<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends State<StaffEditScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.person.name);
  late final TextEditingController _email =
      TextEditingController(text: widget.person.email);
  final _password = TextEditingController();
  final _current = TextEditingController();
  late var _role = widget.person.role;
  late var _active = widget.person.active;
  String? _error;
  var _busy = false;

  bool get _self => widget.person.id == widget.selfId;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _current.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    if (name.isEmpty || !email.contains('@')) {
      setState(() => _error = tr('Check the name and email.'));
      return;
    }
    if (_self && _role != widget.person.role) {
      setState(() => _error = tr('Another admin must change your own role.'));
      return;
    }
    if (_self && !_active) {
      setState(
          () => _error = tr('Another admin must deactivate your own account.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).settings.updateStaff(widget.person.id, {
        'name': name,
        'email': email,
        if (!_self) 'role': _role,
        if (!_self) 'active': _active,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePassword() async {
    final password = _password.text;
    if (password.length < 8 || password.length > 128) {
      setState(() => _error = tr('The new password must be 8–128 characters.'));
      return;
    }
    if (_self && _current.text.isEmpty) {
      setState(() => _error =
          tr('Enter your current password to change your own password.'));
      return;
    }
    if (_self) {
      final ok = await confirmMoney(context,
          title: tr('Your password'),
          body:
              tr('All sessions will end and you will need to sign in again.'));
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).settings.setPassword(
            widget.person.id,
            password: password,
            currentPassword: _self ? _current.text : null,
          );
      if (!mounted) return;
      if (_self) {
        await AppScope.of(context).session.handleUnauthorized();
        return;
      }
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
    final person = widget.person;
    return WorkspaceScaffold(
        title: person.name,
        subtitle: person.email,
        root: false,
        footer: FooterActions(
            error: _error,
            child: AppButton(
                label: tr('Save password'),
                icon: Icons.key_outlined,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _savePassword)),
        children: [
          PaperCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                InitialsAvatar(person.name,
                    letters: 1,
                    tone: _self
                        ? AvatarTone.filled
                        : person.active
                            ? AvatarTone.soft
                            : AvatarTone.muted),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(person.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                          [
                            person.role == 'hub' ? tr('Hub') : tr('Admin'),
                            if (_self) tr('You'),
                          ].join(' · '),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                    ])),
                StatusPill(
                    label: person.active ? tr('Active') : tr('Inactive'),
                    tone: person.active ? ChipTone.green : ChipTone.neutral),
              ])),
          const SizedBox(height: 14),
          FormCard(title: tr('Profile'), children: [
            LabeledField(
                label: tr('Name'),
                child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words)),
            LabeledField(
                label: tr('Email'),
                child: TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false)),
            if (_self)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.lock_outline_rounded,
                        size: 18, color: AppColors.muted)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        tr(
                            'Role: Admin (your own role cannot be changed here)'),
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                            height: 1.45))),
              ])
            else ...[
              LabeledField(
                  label: tr('Role'),
                  helper: _roleNote(_role),
                  child: SegmentPicker<String>(
                      options: _roleOptions(),
                      selected: _role,
                      onChanged: (value) => setState(() => _role = value))),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      FieldLabel(tr('Can sign in')),
                      Text(tr('Switched off accounts cannot sign in.'),
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.muted)),
                    ])),
                const SizedBox(width: 8),
                Semantics(
                    label: tr('Can sign in'),
                    child: Switch(
                        value: _active,
                        onChanged: (value) => setState(() => _active = value))),
              ]),
            ],
            AppButton(
                label: tr('Save profile'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.tonal,
                busy: _busy,
                onPressed: _saveProfile),
          ]),
          const SizedBox(height: 14),
          FormCard(title: tr('Password'), children: [
            if (_self)
              LabeledField(
                  label: tr('Current password'),
                  child: TextField(
                      controller: _current,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false)),
            LabeledField(
                label: tr('New password'),
                helper: tr('8–128 characters'),
                child: TextField(
                    controller: _password,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false)),
          ]),
          const SizedBox(height: 14),
          TipNote(
              text: _self
                  ? tr(
                      'You cannot change your own role. Changing your password signs you out.')
                  : tr('Role and password are saved separately.')),
        ]);
  }
}
