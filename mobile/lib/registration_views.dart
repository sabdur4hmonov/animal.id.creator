import 'package:flutter/material.dart';
import 'local_profiles.dart';
import 'local_registration.dart';
import 'localization.dart';
import 'registry_journal.dart';

UiText _registrationError(Object e) {
  final message = e is StateError ? e.message : null;
  const messages = {
    'Configure backend, operator ID and operator token before registration. Offline capture still works.',
    'This registration belongs to another operator. Use that operator; no new ID was created.',
    'Saved photo operator differs. Configure its original operator; metadata was not changed.',
    'Finish the earlier registry request before registering another animal',
    'Registration or upload is already running',
  };
  return message is String && messages.contains(message)
      ? UiText(message)
      : userError(e);
}

Future<Map<String, dynamic>?> _ownerDialog(BuildContext context) async {
  var id = '', name = '';
  UiText? error;
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, refresh) => AlertDialog(
        title: const FieldText(UiText('Animal owner')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FieldText(
                UiText(
                  'Use a farm reference, not a passport number. Owner details are sent to the configured server.',
                ),
              ),
              TextField(
                maxLength: 64,
                onChanged: (v) => id = v.trim(),
                decoration: InputDecoration(
                  labelText: const UiText(
                    'Owner reference (e.g. FARM-01)',
                  ).resolve(dialog),
                ),
              ),
              TextField(
                maxLength: 120,
                onChanged: (v) => name = v.trim(),
                decoration: InputDecoration(
                  labelText: const UiText('Owner name').resolve(dialog),
                ),
              ),
              if (error != null) FieldText(error!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const FieldText(UiText('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (!validOwnerReference(id) ||
                  name.isEmpty ||
                  name.codeUnits.any((c) => c < 32)) {
                refresh(
                  () => error = const UiText(
                    'Enter a valid owner reference and name.',
                  ),
                );
                return;
              }
              Navigator.pop(dialog, <String, dynamic>{
                'owner_id': id,
                'name': name,
              });
            },
            child: const FieldText(UiText('Register and upload muzzle photos')),
          ),
        ],
      ),
    ),
  );
}

Future<bool> registerLocalAnimal(
  BuildContext context,
  LocalRegistration service,
  LocalProfile profile,
) async {
  Map<String, dynamic>? owner;
  if (await service.mapping(profile.id) == null &&
      await service.intent(profile.id) == null) {
    if (!context.mounted) return false;
    final existing = profile.animal['owner'];
    owner = existing is Map
        ? Map<String, dynamic>.from(existing)
        : await _ownerDialog(context);
    if (owner == null) return false;
  }
  await service.register(profile.id, owner: owner);
  await service.uploadPhotos(profile.id);
  return true;
}

class RegistrationPanel extends StatefulWidget {
  const RegistrationPanel({
    super.key,
    required this.service,
    required this.profile,
  });
  final LocalRegistration service;
  final LocalProfile profile;
  @override
  State<RegistrationPanel> createState() => _RegistrationPanelState();
}

class _RegistrationPanelState extends State<RegistrationPanel> {
  late Future<({Map<String, dynamic>? mapping, int count})> status;
  bool busy = false;
  UiText? error;
  @override
  void initState() {
    super.initState();
    status = _load();
  }

  @override
  void didUpdateWidget(RegistrationPanel old) {
    super.didUpdateWidget(old);
    if (old.profile != widget.profile) status = _load();
  }

  Future<({Map<String, dynamic>? mapping, int count})> _load() async {
    final mapping = await widget.service.mapping(widget.profile.id);
    return (
      mapping: mapping,
      count: mapping == null
          ? widget.profile.photos.length
          : await widget.service.pendingCount(widget.profile, mapping),
    );
  }

  Future<void> _register() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await registerLocalAnimal(context, widget.service, widget.profile);
    } catch (e) {
      error = UiText('Action failed: {0}', [_registrationError(e)]);
    }
    if (mounted) {
      setState(() {
        busy = false;
        status = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldText(UiText('Server registration')),
          FutureBuilder(
            future: status,
            builder: (context, data) {
              if (data.hasError) {
                return FieldText(
                  UiText('Action failed: {0}', [userError(data.error!)]),
                );
              }
              final value = data.data;
              if (value == null) return const LinearProgressIndicator();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (value.mapping != null)
                    SelectableText(
                      '${widget.profile.id} → ${value.mapping!['animal_id']}',
                    )
                  else
                    const FieldText(
                      UiText(
                        'Temporary ID stays on this phone until you register it.',
                      ),
                    ),
                  FieldText(
                    UiText('Muzzle photos not uploaded: {0}', [value.count]),
                  ),
                ],
              );
            },
          ),
          if (!widget.service.configured)
            const FieldText(
              UiText(
                'Configure backend, operator ID and operator token before registration. Offline capture still works.',
              ),
            ),
          if (error != null) FieldText(error!),
          if (busy) const LinearProgressIndicator(),
          OutlinedButton(
            onPressed: busy || !widget.service.configured ? null : _register,
            child: const FieldText(
              UiText('Register on server / retry uploads'),
            ),
          ),
        ],
      ),
    ),
  );
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, required this.service});
  final LocalRegistration service;
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final selected = <String>{};
  bool busy = false;
  int completed = 0;
  UiText? error;
  Future<void> _run() async {
    if (busy) return;
    setState(() {
      busy = true;
      completed = 0;
      error = null;
    });
    try {
      for (final label in selected.toList()) {
        final profile = widget.service.catalog.get(label);
        if (profile == null) {
          throw const FormatException('Saved local animal is missing');
        }
        if (!mounted ||
            !await registerLocalAnimal(context, widget.service, profile)) {
          break;
        }
        if (mounted) setState(() => completed++);
      }
    } catch (e) {
      error = UiText('Action failed: {0}', [_registrationError(e)]);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const FieldText(UiText('Server registration'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FieldText(
            UiText(
              'Choose animals to register and upload. Original offline records stay unchanged.',
            ),
          ),
          if (!widget.service.configured)
            const FieldText(
              UiText(
                'Configure backend, operator ID and operator token before registration. Offline capture still works.',
              ),
            ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) FieldText(error!),
          FieldText(UiText('Completed animals: {0}', [completed])),
          for (final p in widget.service.catalog.profiles)
            CheckboxListTile(
              value: selected.contains(p.id),
              title: Text(p.id),
              subtitle: p.tag.isEmpty ? null : Text(p.tag),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        selected.add(p.id);
                      } else {
                        selected.remove(p.id);
                      }
                    }),
            ),
          FilledButton(
            onPressed: busy || selected.isEmpty || !widget.service.configured
                ? null
                : _run,
            child: const FieldText(UiText('Register selected animals')),
          ),
        ],
      ),
    ),
  );
}
