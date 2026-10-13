import 'dart:io';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'animal_id.dart';
import 'app_design.dart';
import 'capture_environment.dart';
import 'registry_journal.dart';
import 'species.dart';

const _numberStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.3,
  fontFeatures: [FontFeature.tabularFigures()],
  color: FieldColors.forest,
);

Future<Map<String, dynamic>?> issueAnimalDialog(
  BuildContext context,
  ApiClient api,
  RegistryJournal journal,
  SpeciesConfig config,
) async {
  final pending = await journal.waiting(registryRoot);
  final previous = await journal.issued();
  Map<String, dynamic>? assigned;
  for (final item in previous) {
    if (item['_delivered'] != true) {
      assigned = item;
      break;
    }
  }
  if (pending != null && pending.body['species'] != config.species.name ||
      assigned != null && assigned['species'] != config.species.name) {
    throw StateError(
      'Finish the earlier species registration before issuing another ID',
    );
  }
  if (!context.mounted) return null;
  final ownerId = TextEditingController(
    text: pending?.body['owner']?['owner_id'] as String?,
  );
  final ownerName = TextEditingController(
    text: pending?.body['owner']?['name'] as String?,
  );
  final form = GlobalKey<FormState>();
  var busy = false;
  String? error;
  Future<void> useId(BuildContext context, Map<String, dynamic> item) async {
    final current = Map<String, dynamic>.from(
      await api.registryGet(
            '$registryRoot/${item['species']}/${item['animal_id']}',
          )
          as Map,
    );
    await journal.confirmIssued(item['_request_key'] as String);
    if (context.mounted) Navigator.pop(context, current);
  }

  try {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => PopScope(
          canPop: !busy,
          child: AlertDialog(
            title: Text(
              assigned != null
                  ? 'Your permanent animal ID'
                  : pending == null
                  ? 'Register a new animal'
                  : 'Retry pending registration',
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (assigned != null) ...[
                        Text(
                          assigned!['animal_id'] as String,
                          style: _numberStyle,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Owner at registration: ${assigned!['owner']['name']} · ${assigned!['owner']['owner_id']}',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'This number has been issued. Write it on the animal tag/ledger. Use this same ID for every future capture; reconnect to confirm it if needed.',
                        ),
                      ] else ...[
                        Text(
                          'The backend issues IDs such as ${config.numberingExample ?? 'the configured species number'}. Register each animal once; retries keep the same request.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: ownerId,
                          enabled: !busy && pending == null,
                          decoration: const InputDecoration(
                            labelText: 'Owner reference',
                            hintText: 'e.g. OWNER-001',
                          ),
                          validator: (value) =>
                              validOwnerReference(value?.trim())
                              ? null
                              : 'Use 1–64 letters, digits, underscores or hyphens',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: ownerName,
                          enabled: !busy && pending == null,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Owner name',
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Enter an owner name'
                              : null,
                        ),
                      ],
                      if (previous.isNotEmpty &&
                          pending == null &&
                          assigned == null) ...[
                        const Text(
                          'Already registered? Reuse a recent ID instead.',
                          style: TextStyle(fontSize: 12),
                        ),
                        for (final item in previous.take(5))
                          TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    refresh(() => busy = true);
                                    try {
                                      await useId(context, item);
                                    } catch (value) {
                                      if (context.mounted) {
                                        refresh(() {
                                          busy = false;
                                          error = '$value';
                                        });
                                      }
                                    }
                                  },
                            child: Text(
                              item['animal_id'] as String,
                              style: _numberStyle,
                            ),
                          ),
                      ],
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            error!,
                            style: const TextStyle(color: FieldColors.red),
                          ),
                        ),
                      if (busy) const LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (assigned == null &&
                            !form.currentState!.validate()) {
                          return;
                        }
                        refresh(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          if (assigned != null) {
                            await useId(context, assigned!);
                          } else {
                            final body =
                                pending?.body ??
                                {
                                  'species': config.species.name,
                                  'owner': {
                                    'owner_id': ownerId.text.trim(),
                                    'name': ownerName.text.trim(),
                                  },
                                };
                            final response = await journal.submit(
                              registryRoot,
                              body,
                              api,
                            );
                            if (context.mounted) {
                              refresh(() {
                                assigned = response;
                                busy = false;
                              });
                            }
                          }
                        } catch (value) {
                          if (context.mounted) {
                            refresh(() {
                              busy = false;
                              error =
                                  '$value. Retry uses the same registration.';
                            });
                          }
                        }
                      },
                child: Text(
                  assigned != null
                      ? 'Use this ID'
                      : pending == null
                      ? 'Issue unique ID'
                      : 'Retry same request',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    ownerId.dispose();
    ownerName.dispose();
  }
}

class AnimalRegistryScreen extends StatefulWidget {
  final CaptureEnvironment environment;
  final Directory queueRoot;
  final List<SpeciesConfig> configs;
  final ValueChanged<Map<String, dynamic>> onCapture;
  const AnimalRegistryScreen({
    super.key,
    required this.environment,
    required this.queueRoot,
    required this.configs,
    required this.onCapture,
  });
  @override
  State<AnimalRegistryScreen> createState() => _AnimalRegistryState();
}

class _AnimalRegistryState extends State<AnimalRegistryScreen> {
  late final RegistryJournal journal;
  late SpeciesConfig config;
  final lookup = TextEditingController();
  List<Map<String, dynamic>> animals = [];
  Map<String, dynamic>? selected;
  List<Map<String, dynamic>> history = [];
  Map<String, dynamic>? slaughterCheck;
  List<RegistryRequest> pending = [];
  bool busy = false, archived = false;
  int offset = 0;
  String? message;
  @override
  void initState() {
    super.initState();
    config = widget.configs.first;
    journal = RegistryJournal(
      widget.queueRoot,
      widget.environment.backend,
      widget.environment.operatorId,
    );
    reload();
  }

  @override
  void dispose() {
    lookup.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final waiting = await journal.pending();
      if (mounted) setState(() => pending = waiting);
      final rows = await widget.environment.api.registryGet(
        '$registryRoot?species=${config.species.name}&lifecycle=${archived ? 'all' : 'active'}&limit=50&offset=$offset',
      );
      if (mounted) {
        setState(() {
          animals = (rows as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
          pending = waiting;
          message = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => message =
              '$error. Registry lookup needs the backend; saved captures stay on this phone.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String route(Map<String, dynamic> animal) =>
      '$registryRoot/${animal['species']}/${animal['animal_id']}';
  Future<void> open(String id) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final path = '$registryRoot/${config.species.name}/$id';
      final animal = Map<String, dynamic>.from(
        await widget.environment.api.registryGet(path) as Map,
      );
      final events = await widget.environment.api.registryGet(
        '$path/history?limit=50',
      );
      final check = Map<String, dynamic>.from(
        await widget.environment.api.registryGet('$path/slaughter-check')
            as Map,
      );
      if (mounted) {
        setState(() {
          selected = animal;
          history = (events as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          slaughterCheck = check;
          message = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => message = '$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> newAnimal() async {
    try {
      final animal = await issueAnimalDialog(
        context,
        widget.environment.api,
        journal,
        config,
      );
      if (animal != null && mounted) {
        await reload();
        await open(animal['animal_id'] as String);
      }
    } catch (error) {
      if (mounted) setState(() => message = '$error');
    }
  }

  Future<void> retry() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final results = await journal.retry(widget.environment.api);
      if (mounted) {
        setState(
          () => message = '${results.length} registry changes acknowledged.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => message =
              '$error. Uncertain requests keep the same key; rejected changes require a fresh review.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    final text = message;
    await reload();
    if (mounted) setState(() => message = text);
    if (selected != null) await open(selected!['animal_id'] as String);
  }

  Future<void> change(String kind) async {
    final animal = selected!;
    final path = '${route(animal)}/${kind == 'owner' ? 'owner' : 'retirement'}';
    RegistryRequest? waiting;
    try {
      waiting = await journal.waiting(path);
      if (waiting != null &&
          kind != 'owner' &&
          waiting.body['lifecycle'] != kind) {
        throw StateError(
          'A different terminal report is pending. Retry that original report first.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => message = '$error');
      return;
    }
    if (!mounted) return;
    final ownerId = TextEditingController(
      text: waiting?.body['owner']?['owner_id'] as String?,
    );
    final ownerName = TextEditingController(
      text: waiting?.body['owner']?['name'] as String?,
    );
    final reason = TextEditingController(
      text: waiting?.body['reason'] as String?,
    );
    final facility = TextEditingController(
      text: waiting?.body['facility_id'] as String?,
    );
    final form = GlobalKey<FormState>();
    var saving = false;
    var rejected = false;
    String? error;
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, refresh) => PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: Text(
                kind == 'owner'
                    ? 'Change owner'
                    : kind == 'deceased'
                    ? 'Record death'
                    : 'Record slaughter',
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          animal['animal_id'] as String,
                          style: _numberStyle,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          kind == 'owner'
                              ? 'The animal keeps its ID and complete ownership history.'
                              : 'Removes this animal from the active list. Its ID and evidence remain permanently reserved. This records your report, not independent proof of physical identity/slaughter.',
                        ),
                        const SizedBox(height: 16),
                        if (waiting != null)
                          const Text(
                            'A pending request already exists. Retry its original details.',
                            style: TextStyle(color: FieldColors.amber),
                          ),
                        if (kind == 'owner') ...[
                          TextFormField(
                            controller: ownerId,
                            enabled: !saving && waiting == null,
                            decoration: const InputDecoration(
                              labelText: 'New owner reference',
                            ),
                            validator: (value) =>
                                validOwnerReference(value?.trim())
                                ? null
                                : 'Enter a valid owner reference',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: ownerName,
                            enabled: !saving && waiting == null,
                            maxLength: 120,
                            decoration: const InputDecoration(
                              labelText: 'New owner name',
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Enter a name'
                                : null,
                          ),
                        ],
                        if (kind == 'slaughtered') ...[
                          TextFormField(
                            controller: facility,
                            enabled: !saving && waiting == null,
                            decoration: const InputDecoration(
                              labelText: 'Slaughter facility ID',
                            ),
                            validator: (value) =>
                                validOwnerReference(value?.trim())
                                ? null
                                : 'Enter a facility reference',
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: reason,
                          enabled: !saving && waiting == null,
                          maxLength: 1000,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Reason / report notes',
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'A reason is required'
                              : null,
                        ),
                        if (error != null)
                          Text(
                            error!,
                            style: const TextStyle(color: FieldColors.red),
                          ),
                        if (saving) const LinearProgressIndicator(),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving || rejected
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          refresh(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            Map<String, dynamic> body;
                            if (waiting != null) {
                              body = waiting!.body;
                            } else {
                              final gps = await widget.environment.gps();
                              body = {
                                'expected_version': animal['version'],
                                'observed_at': widget.environment
                                    .now()
                                    .toUtc()
                                    .toIso8601String(),
                                'gps': gps?['gps'],
                                'reason': reason.text.trim(),
                                if (kind == 'owner')
                                  'owner': {
                                    'owner_id': ownerId.text.trim(),
                                    'name': ownerName.text.trim(),
                                  }
                                else
                                  'lifecycle': kind,
                                if (kind == 'slaughtered')
                                  'facility_id': facility.text.trim(),
                              };
                            }
                            await journal.submit(
                              path,
                              body,
                              widget.environment.api,
                            );
                            if (context.mounted) Navigator.pop(context, true);
                          } catch (value) {
                            if (context.mounted) {
                              if (value is RegistryApiError &&
                                  {404, 409, 422}.contains(value.status)) {
                                refresh(() {
                                  saving = false;
                                  rejected = true;
                                  error =
                                      '$value. Not applied; cancel and reload before submitting a corrected change.';
                                });
                              } else {
                                try {
                                  waiting = await journal.waiting(path);
                                } catch (_) {}
                                if (context.mounted) {
                                  refresh(() {
                                    saving = false;
                                    error =
                                        '$value. Retry keeps the original recorded details.';
                                  });
                                }
                              }
                            }
                          }
                        },
                  child: Text(
                    waiting != null
                        ? 'Retry same request'
                        : kind == 'owner'
                        ? 'Confirm owner change'
                        : 'Confirm ${kind == 'deceased' ? 'death' : 'slaughter'} report',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted) {
        await reload();
        await open(animal['animal_id'] as String);
      }
    } finally {
      ownerId.dispose();
      ownerName.dispose();
      reason.dispose();
      facility.dispose();
    }
  }

  Widget detail() {
    final animal = selected!;
    final active = animal['lifecycle'] == 'active';
    final manage = animal['can_manage'] == true && active;
    final terminal = animal['terminal_record'] as Map?;
    return FieldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(animal['animal_id'] as String, style: _numberStyle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FieldTag(
                animal['lifecycle'] as String,
                icon: active ? Icons.grass : Icons.archive_outlined,
                caution: !active,
              ),
              FieldTag(
                'Financial: ${animal['status']}',
                icon: Icons.description_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Owner', style: Theme.of(context).textTheme.titleMedium),
          Text(
            animal['owner'] == null
                ? 'Not recorded'
                : '${animal['owner']['name']} · ${animal['owner']['owner_id']}',
          ),
          const SizedBox(height: 16),
          Text(
            slaughterCheck?['recorded_slaughter'] == true
                ? 'Slaughter report on file'
                : 'No slaughter report on file',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Registry record only. Physical slaughter and biometric identity are not independently verified.',
            style: TextStyle(fontSize: 12),
          ),
          if (terminal != null) ...[
            const SizedBox(height: 12),
            Text(
              'Facility: ${terminal['facility_id'] ?? 'Not applicable'}\nRecorded by: ${terminal['actor_id']}\nReported time: ${terminal['observed_at']}\nReceived: ${terminal['received_at']}\nReason: ${terminal['reason']}',
            ),
          ],
          const SizedBox(height: 16),
          if (active)
            OutlinedButton.icon(
              onPressed: busy ? null : () => widget.onCapture(animal),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Capture with this ID'),
            ),
          if (manage) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy ? null : () => change('owner'),
              child: Text(
                animal['owner'] == null ? 'Record owner' : 'Change owner',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => change('deceased'),
                  child: const Text('Record death'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => change('slaughtered'),
                  child: const Text('Record slaughter'),
                ),
              ],
            ),
          ],
          if (!active)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Archived. History retained; this ID will never be reassigned.',
              ),
            ),
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Ownership & event history'),
            children: [
              for (final event in history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(event['action'] as String),
                  subtitle: Text(
                    '${event['actor_id']} · ${event['received_at']}\n${event['details']}',
                  ),
                ),
            ],
          ),
          TextButton(
            onPressed: () => setState(() {
              selected = null;
              slaughterCheck = null;
              history = [];
            }),
            child: const Text('Back to animals'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldHeading(
          eyebrow: 'Animal registry',
          title: 'An ID for life.',
          subtitle: 'Owners change. Animal numbers stay the same.',
        ),
        const SizedBox(height: 16),
        if (widget.configs.length > 1)
          DropdownButtonFormField<SpeciesConfig>(
            initialValue: config,
            decoration: const InputDecoration(labelText: 'Species'),
            items: widget.configs
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.species.name),
                  ),
                )
                .toList(),
            onChanged: busy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        config = value;
                        offset = 0;
                        selected = null;
                      });
                      reload();
                    }
                  },
          ),
        FieldCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: lookup,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: 'Look up animal ID',
                  hintText: config.numberingExample == null
                      ? 'Enter the ID from the tag or ledger'
                      : 'e.g. ${config.numberingExample} or an existing ID',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        final id = lookup.text.trim();
                        if (validateAnimalId(id) != null) {
                          setState(() => message = 'Enter a valid animal ID');
                          return;
                        }
                        open(id);
                      },
                icon: const Icon(Icons.search),
                label: const Text('Check animal / slaughter record'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy || config.numbering == null ? null : newAnimal,
                icon: const Icon(Icons.add),
                label: const Text('Register new animal'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (busy) const LinearProgressIndicator(),
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              message!,
              style: const TextStyle(color: FieldColors.amber),
            ),
          ),
        if (pending.isNotEmpty)
          FieldCard(
            color: FieldColors.cream,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${pending.length} registry changes waiting for acknowledgement',
                ),
                TextButton(
                  onPressed: busy ? null : retry,
                  child: const Text('Retry pending registry changes'),
                ),
              ],
            ),
          ),
        for (final issue in journal.issues)
          Text(issue, style: const TextStyle(color: FieldColors.red)),
        if (selected != null)
          detail()
        else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include archived animals'),
            value: archived,
            onChanged: busy
                ? null
                : (value) {
                    setState(() {
                      archived = value;
                      offset = 0;
                    });
                    reload();
                  },
          ),
          if (animals.isEmpty && !busy)
            const FieldCard(
              child: Text(
                'No animals in this view. Connect to the backend to review the registry.',
              ),
            ),
          for (final animal in animals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FieldCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(
                    animal['animal_id'] as String,
                    style: _numberStyle,
                  ),
                  subtitle: Text(
                    '${animal['owner']?['name'] ?? 'Owner not recorded'} · ${animal['lifecycle']}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy
                      ? null
                      : () => open(animal['animal_id'] as String),
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: busy || offset == 0
                    ? null
                    : () {
                        setState(() => offset -= 50);
                        reload();
                      },
                child: const Text('Previous animals'),
              ),
              Text('Page ${offset ~/ 50 + 1}'),
              TextButton(
                onPressed: busy || animals.length < 50
                    ? null
                    : () {
                        setState(() => offset += 50);
                        reload();
                      },
                child: const Text('Next animals'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
