import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/workspace.dart';
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
    return Scaffold(
      appBar: const BackTitle(title: 'স্টাফ'),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
          children: [
            const PageHeader(title: 'স্টাফ', subtitle: 'অ্যাডমিন সব দেখে। হাব ম্যানেজার টাকা ও কাস্টমারের নাম দেখে না।'),
            if (_loading && _staff.isEmpty) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
            if (_error != null) ...[
              ErrorNote(message: _error!, onRetry: _load),
              const SizedBox(height: 12),
            ],
            for (final person in _staff) ...[
              DirectoryTile(
                title: person.name,
                subtitle: '${person.email}\n${person.role == 'hub' ? 'হাব' : 'অ্যাডমিন'}${person.id == self ? ' · আপনি' : ''}',
                badge: person.active ? 'সক্রিয়' : 'বন্ধ',
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => StaffEditScreen(person: person, selfId: self)));
                  if (changed == true && mounted) await _load();
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            AppButton(
              label: 'নতুন স্টাফ',
              kind: AppButtonKind.current,
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const StaffCreateScreen()));
                if (changed == true && mounted) await _load();
              },
            ),
          ],
        ),
      ),
    );
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
    if (name.isEmpty || !email.contains('@') || password.length < 8 || password.length > 128) {
      setState(() => _error = 'নাম, ইমেইল ও ৮–১২৮ অক্ষরের পাসওয়ার্ড দিন।');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).settings.createStaff(name: name, email: email, role: _role, password: password);
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
    return Scaffold(
      appBar: const BackTitle(title: 'নতুন স্টাফ'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          const PageHeader(title: 'নতুন স্টাফ', subtitle: 'হাব ম্যানেজার শিপমেন্ট হ্যান্ডেল করে। টাকার কাজ অ্যাডমিনের।'),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'নাম')),
          const SizedBox(height: 8),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ইমেইল')),
          const SizedBox(height: 8),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'পাসওয়ার্ড', helperText: '৮–১২৮ অক্ষর')),
          const SizedBox(height: 12),
          ChoiceChips(
            options: const [(value: 'hub', label: 'হাব'), (value: 'admin', label: 'অ্যাডমিন')],
            selected: _role,
            onSelected: (value) => setState(() => _role = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
          const SizedBox(height: 16),
          AppButton(label: 'স্টাফ তৈরি', kind: AppButtonKind.current, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

class StaffEditScreen extends StatefulWidget {
  const StaffEditScreen({super.key, required this.person, required this.selfId});

  final StaffAccount person;
  final String? selfId;

  @override
  State<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends State<StaffEditScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.person.name);
  late final TextEditingController _email = TextEditingController(text: widget.person.email);
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
      setState(() => _error = 'নাম ও ইমেইল ঠিক করুন।');
      return;
    }
    if (_self && _role != widget.person.role) {
      setState(() => _error = 'নিজের রোল অন্য অ্যাডমিন বদলাবে।');
      return;
    }
    if (_self && !_active) {
      setState(() => _error = 'নিজের অ্যাকাউন্ট অন্য অ্যাডমিন বন্ধ করবে।');
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
      setState(() => _error = 'নতুন পাসওয়ার্ড ৮–১২৮ অক্ষর।');
      return;
    }
    if (_self && _current.text.isEmpty) {
      setState(() => _error = 'নিজের পাসওয়ার্ড বদলাতে বর্তমান পাসওয়ার্ড দিন।');
      return;
    }
    if (_self) {
      final ok = await confirmMoney(context, title: 'নিজের পাসওয়ার্ড', body: 'সব সেশন কেটে যাবে এবং আবার লগইন করতে হবে।');
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
    return Scaffold(
      appBar: BackTitle(title: widget.person.name),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          PageHeader(title: widget.person.name, subtitle: _self ? 'নিজের রোল বদলানো যায় না। পাসওয়ার্ড বদলালে লগআউট হবে।' : 'রোল ও পাসওয়ার্ড আলাদা সেভ হয়।'),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'নাম')),
          const SizedBox(height: 8),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'ইমেইল')),
          const SizedBox(height: 12),
          if (_self)
            const Text('রোল: অ্যাডমিন (নিজের রোল এখানে বদলায় না)', style: TextStyle(color: AppColors.muted, height: 1.35))
          else ...[
            const SectionTitle(title: 'রোল'),
            ChoiceChips(
              options: const [(value: 'admin', label: 'অ্যাডমিন'), (value: 'hub', label: 'হাব')],
              selected: _role,
              onSelected: (value) => setState(() => _role = value),
            ),
            const SizedBox(height: 8),
            ChoiceChips(
              options: const [(value: 'on', label: 'সক্রিয়'), (value: 'off', label: 'বন্ধ')],
              selected: _active ? 'on' : 'off',
              onSelected: (value) => setState(() => _active = value == 'on'),
            ),
          ],
          const SizedBox(height: 12),
          AppButton(label: 'প্রোফাইল সেভ', kind: AppButtonKind.teal, busy: _busy, onPressed: _saveProfile),
          const SizedBox(height: 20),
          const SectionTitle(title: 'পাসওয়ার্ড'),
          if (_self) ...[
            TextField(controller: _current, obscureText: true, decoration: const InputDecoration(labelText: 'বর্তমান পাসওয়ার্ড')),
            const SizedBox(height: 8),
          ],
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
          const SizedBox(height: 12),
          AppButton(label: 'পাসওয়ার্ড সেভ', kind: AppButtonKind.current, busy: _busy, onPressed: _savePassword),
        ],
      ),
    );
  }
}
