import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/workspace.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/money_confirm.dart';
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

  @override
  Widget build(BuildContext context) {
    final self = AppScope.of(context).session.user?.id;
    return WorkspaceScaffold(
        title: tr('Staff'),
        root: false,
        onRefresh: _load,
        footer: ActionFooter(
            child: AppButton(
          label: tr('New staff'),
          kind: AppButtonKind.current,
          onPressed: () async {
            final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const StaffCreateScreen()));
            if (changed == true && mounted) await _load();
          },
        )),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'Admins see everything. Hub managers do not see money or customer names.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading && _staff.isEmpty)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ...[
            ErrorNote(message: _error!, onRetry: _load),
            const SizedBox(height: 12),
          ],
          for (final person in _staff) ...[
            DirectoryTile(
              title: person.name,
              subtitle: [
                person.email,
                [
                  person.role == 'hub' ? tr('Hub') : tr('Admin'),
                  if (person.id == self) tr('You'),
                ].join(' · '),
              ].join('\n'),
              badge: person.active ? tr('Active') : tr('Inactive'),
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) =>
                            StaffEditScreen(person: person, selfId: self)));
                if (changed == true && mounted) await _load();
              },
            ),
            const SizedBox(height: 8),
          ],
        ]);
  }
}

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
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Create staff'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'Hub managers handle shipments. Money is handled by admins.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          TextField(
              controller: _name,
              decoration: InputDecoration(labelText: tr('Name'))),
          const SizedBox(height: 8),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: tr('Email'))),
          const SizedBox(height: 8),
          TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                  labelText: tr('Password'),
                  helperText: tr('8–128 characters'))),
          const SizedBox(height: 12),
          ChoiceChips(
            options: [
              (value: 'hub', label: tr('Hub')),
              (value: 'admin', label: tr('Admin'))
            ],
            selected: _role,
            onSelected: (value) => setState(() => _role = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
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
    return WorkspaceScaffold(
        title: widget.person.name,
        root: false,
        subtitle: widget.person.name,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save password'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _savePassword)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  _self
                      ? tr(
                          'You cannot change your own role. Changing your password signs you out.')
                      : tr('Role and password are saved separately.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          TextField(
              controller: _name,
              decoration: InputDecoration(labelText: tr('Name'))),
          const SizedBox(height: 8),
          TextField(
              controller: _email,
              decoration: InputDecoration(labelText: tr('Email'))),
          const SizedBox(height: 12),
          if (_self)
            Text(tr('Role: Admin (your own role cannot be changed here)'),
                style: const TextStyle(color: AppColors.muted, height: 1.35))
          else ...[
            SectionTitle(title: tr('Role')),
            ChoiceChips(
              options: [
                (value: 'admin', label: tr('Admin')),
                (value: 'hub', label: tr('Hub'))
              ],
              selected: _role,
              onSelected: (value) => setState(() => _role = value),
            ),
            const SizedBox(height: 8),
            ChoiceChips(
              options: [
                (value: 'on', label: tr('Active')),
                (value: 'off', label: tr('Inactive'))
              ],
              selected: _active ? 'on' : 'off',
              onSelected: (value) => setState(() => _active = value == 'on'),
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
              label: tr('Save profile'),
              kind: AppButtonKind.teal,
              busy: _busy,
              onPressed: _saveProfile),
          const SizedBox(height: 20),
          SectionTitle(title: tr('Password')),
          if (_self) ...[
            TextField(
                controller: _current,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('Current password'))),
            const SizedBox(height: 8),
          ],
          TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: tr('New password'))),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
        ]);
  }
}
