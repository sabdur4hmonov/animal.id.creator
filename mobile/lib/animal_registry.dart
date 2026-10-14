import 'dart:io';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'localization.dart';
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

bool validCaptureReference(String value) => RegExp(
  r'^[a-fA-F0-9]{8}(?:-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$',
).hasMatch(value);

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
  Object? error;
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
            title: FieldText(
              assigned != null
                  ? UiText("Your permanent animal ID")
                  : pending == null
                  ? UiText("Register a new animal")
                  : UiText("Retry pending registration"),
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
                        FieldText(
                          assigned!['animal_id'] as String,
                          style: _numberStyle,
                        ),
                        const SizedBox(height: 12),
                        FieldText(
                          UiText("Owner at registration: {0} · {1}", [
                            assigned!['owner']['name'],
                            assigned!['owner']['owner_id'],
                          ]),
                        ),
                        const SizedBox(height: 12),
                        const FieldText(
                          UiText(
                            "This number has been issued. Write it on the animal tag/ledger. Use this same ID for every future capture; reconnect to confirm it if needed.",
                          ),
                        ),
                      ] else ...[
                        FieldText(
                          UiText(
                            "The backend issues IDs such as {0}. Register each animal once; retries keep the same request.",
                            [
                              config.numberingExample ??
                                  const UiText('the configured species number'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: ownerId,
                          enabled: !busy && pending == null,
                          decoration: const InputDecoration(
                            label: FieldText(UiText("Owner reference")),
                            hint: FieldText(UiText("e.g. OWNER-001")),
                          ),
                          validator: (value) =>
                              validOwnerReference(value?.trim())
                              ? null
                              : UiText(
                                  "Use 1–64 letters, digits, underscores or hyphens",
                                ).resolve(context),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: ownerName,
                          enabled: !busy && pending == null,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            label: FieldText(UiText("Owner name")),
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? UiText("Enter an owner name").resolve(context)
                              : null,
                        ),
                      ],
                      if (previous.isNotEmpty &&
                          pending == null &&
                          assigned == null) ...[
                        const FieldText(
                          UiText(
                            "Already registered? Reuse a recent ID instead.",
                          ),
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
                                          error = userError(value);
                                        });
                                      }
                                    }
                                  },
                            child: FieldText(
                              item['animal_id'] as String,
                              style: _numberStyle,
                            ),
                          ),
                      ],
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: FieldText(
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
                child: const FieldText(UiText("Cancel")),
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
                              error = UiText(
                                "{0}. Retry uses the same registration.",
                                [userError(value)],
                              );
                            });
                          }
                        }
                      },
                child: FieldText(
                  assigned != null
                      ? UiText("Use this ID")
                      : pending == null
                      ? UiText("Issue unique ID")
                      : UiText("Retry same request"),
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
  int historyOffset = 0;
  bool historyExpanded = false;
  Object? message;
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
        setState(() {
          animals = [];
          selected = null;
          slaughterCheck = null;
          history = [];
          message = UiText(
            "{0}. Registry lookup needs the backend; saved captures stay on this phone.",
            [userError(error)],
          );
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String route(Map<String, dynamic> animal) =>
      '$registryRoot/${animal['species']}/${animal['animal_id']}';
  Future<void> open(String id) async {
    if (busy) return;
    setState(() {
      busy = true;
      selected = null;
      slaughterCheck = null;
      history = [];
      historyOffset = 0;
      historyExpanded = false;
    });
    try {
      final path = '$registryRoot/${config.species.name}/$id';
      final check = Map<String, dynamic>.from(
        await widget.environment.api.registryGet('$path/slaughter-check')
            as Map,
      );
      final animal = Map<String, dynamic>.from(check['animal'] as Map);
      if (animal['animal_id'] != id ||
          animal['species'] != config.species.name) {
        throw const FormatException(
          'Registry response does not match the requested animal',
        );
      }
      final events = await widget.environment.api.registryGet(
        '$path/history?limit=50',
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
      if (mounted) setState(() => message = userError(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> historyPage(int pageOffset) async {
    if (busy || selected == null) return;
    final path = route(selected!);
    setState(() => busy = true);
    try {
      final rows = await widget.environment.api.registryGet(
        '$path/history?limit=50&offset=$pageOffset',
      );
      if (mounted) {
        setState(() {
          history = (rows as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          historyOffset = pageOffset;
          message = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => message = UiText(
            "History page unavailable: {0}. Showing the previous page.",
            [userError(error)],
          ),
        );
      }
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
      if (mounted) setState(() => message = userError(error));
    }
  }

  Future<void> retry() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final results = await journal.retry(widget.environment.api);
      if (mounted) {
        setState(
          () => message = UiText("{0} registry changes acknowledged.", [
            results.length,
          ]),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => message = UiText(
            "{0}. Uncertain requests keep the same key; rejected changes require a fresh review.",
            [userError(error)],
          ),
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
      if (mounted) setState(() => message = userError(error));
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
    final captureId = TextEditingController(
      text: waiting?.body['capture_id'] as String?,
    );
    final form = GlobalKey<FormState>();
    var saving = false;
    var rejected = false;
    Object? error;
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, refresh) => PopScope(
            canPop: !saving,
            child: AlertDialog(
              title: FieldText(
                kind == 'owner'
                    ? UiText("Change owner")
                    : kind == 'deceased'
                    ? UiText("Record death")
                    : UiText("Record slaughter"),
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
                        FieldText(
                          animal['animal_id'] as String,
                          style: _numberStyle,
                        ),
                        const SizedBox(height: 12),
                        FieldText(
                          kind == 'owner'
                              ? UiText(
                                  "The animal keeps its ID and complete ownership history.",
                                )
                              : UiText(
                                  "Removes this animal from the active list. Its ID and evidence remain permanently reserved. This records your report, not independent proof of physical identity/slaughter.",
                                ),
                        ),
                        const SizedBox(height: 16),
                        if (waiting != null)
                          const FieldText(
                            UiText(
                              "A pending request already exists. Retry its original details.",
                            ),
                            style: TextStyle(color: FieldColors.amber),
                          ),
                        if (kind == 'owner') ...[
                          TextFormField(
                            controller: ownerId,
                            enabled: !saving && waiting == null,
                            decoration: const InputDecoration(
                              label: FieldText(UiText("New owner reference")),
                            ),
                            validator: (value) =>
                                validOwnerReference(value?.trim())
                                ? null
                                : UiText(
                                    "Enter a valid owner reference",
                                  ).resolve(context),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: ownerName,
                            enabled: !saving && waiting == null,
                            maxLength: 120,
                            decoration: const InputDecoration(
                              label: FieldText(UiText("New owner name")),
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? UiText("Enter a name").resolve(context)
                                : null,
                          ),
                        ],
                        if (kind == 'slaughtered') ...[
                          TextFormField(
                            controller: facility,
                            enabled: !saving && waiting == null,
                            decoration: const InputDecoration(
                              label: FieldText(UiText("Slaughter facility ID")),
                            ),
                            validator: (value) =>
                                validOwnerReference(value?.trim())
                                ? null
                                : UiText(
                                    "Enter a facility reference",
                                  ).resolve(context),
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
                            label: FieldText(UiText("Reason / report notes")),
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? UiText("A reason is required").resolve(context)
                              : null,
                        ),
                        if (kind != 'owner') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: captureId,
                            enabled: !saving && waiting == null,
                            decoration: const InputDecoration(
                              label: FieldText(
                                UiText("Uploaded capture UUID (optional)"),
                              ),
                              helper: FieldText(
                                UiText(
                                  "Copy from Saved upload receipts. Must belong to this animal; a local request key is not a capture UUID.",
                                ),
                              ),
                              helperMaxLines: 4,
                            ),
                            validator: (value) =>
                                value!.trim().isEmpty ||
                                    validCaptureReference(value.trim())
                                ? null
                                : UiText(
                                    "Enter a valid uploaded capture UUID or leave blank",
                                  ).resolve(context),
                          ),
                        ],
                        if (error != null)
                          FieldText(
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
                  child: const FieldText(UiText("Cancel")),
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
                                if (kind != 'owner' &&
                                    captureId.text.trim().isNotEmpty)
                                  'capture_id': captureId.text
                                      .trim()
                                      .toLowerCase(),
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
                                  error = UiText(
                                    "{0}. Not applied; cancel and reload before submitting a corrected change.",
                                    [userError(value)],
                                  );
                                });
                              } else {
                                try {
                                  waiting = await journal.waiting(path);
                                } catch (_) {}
                                if (context.mounted) {
                                  refresh(() {
                                    saving = false;
                                    error = UiText(
                                      "{0}. Retry keeps the original recorded details.",
                                      [userError(value)],
                                    );
                                  });
                                }
                              }
                            }
                          }
                        },
                  child: FieldText(
                    waiting != null
                        ? UiText("Retry same request")
                        : kind == 'owner'
                        ? UiText("Confirm owner change")
                        : kind == 'deceased'
                        ? const UiText('Confirm death report')
                        : const UiText('Confirm slaughter report'),
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
      captureId.dispose();
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
          FieldText(animal['animal_id'] as String, style: _numberStyle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FieldTag(
                statusLabel(animal['lifecycle'] as String),
                icon: active ? Icons.grass : Icons.archive_outlined,
                caution: !active,
              ),
              FieldTag(
                UiText("Financial: {0}", [
                  statusLabel(animal['status'] as String),
                ]),
                icon: Icons.description_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          FieldText(
            UiText("Owner"),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          FieldText(
            animal['owner'] == null
                ? UiText("Not recorded")
                : '${animal['owner']['name']} · ${animal['owner']['owner_id']}',
          ),
          const SizedBox(height: 16),
          FieldText(
            slaughterCheck?['recorded_slaughter'] == true
                ? UiText("Slaughter report on file")
                : UiText("No slaughter report on file"),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const FieldText(
            UiText(
              "Registry record only. Physical slaughter and biometric identity are not independently verified.",
            ),
            style: TextStyle(fontSize: 12),
          ),
          if (terminal != null) ...[
            const SizedBox(height: 12),
            FieldText(
              UiText(
                "Facility: {0}\nRecorded by: {1}\nReported time: {2}\nReceived: {3}\nReason: {4}",
                [
                  terminal['facility_id'] ?? const UiText('Not applicable'),
                  terminal['actor_id'],
                  terminal['observed_at'],
                  terminal['received_at'],
                  terminal['reason'],
                ],
              ),
            ),
            const SizedBox(height: 8),
            FieldSelectableText(
              UiText("Capture evidence: {0}", [
                terminal['capture_id'] ?? const UiText('Not attached'),
              ]),
            ),
            if (terminal['capture_stored_sha256'] != null)
              FieldSelectableText(
                UiText("Stored image SHA-256: {0}", [
                  terminal['capture_stored_sha256'],
                ]),
              ),
          ],
          const SizedBox(height: 16),
          if (active)
            OutlinedButton.icon(
              onPressed: busy ? null : () => widget.onCapture(animal),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const FieldText(UiText("Capture with this ID")),
            ),
          if (manage) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy ? null : () => change('owner'),
              child: FieldText(
                animal['owner'] == null
                    ? UiText("Record owner")
                    : UiText("Change owner"),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : () => change('deceased'),
                  child: const FieldText(UiText("Record death")),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => change('slaughtered'),
                  child: const FieldText(UiText("Record slaughter")),
                ),
              ],
            ),
          ],
          if (!active)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: FieldText(
                UiText(
                  "Archived. History retained; this ID will never be reassigned.",
                ),
              ),
            ),
          const SizedBox(height: 16),
          ExpansionTile(
            key: ValueKey('history-${animal['animal_id']}-$historyExpanded'),
            initiallyExpanded: historyExpanded,
            onExpansionChanged: (value) => historyExpanded = value,
            tilePadding: EdgeInsets.zero,
            title: const FieldText(UiText("Ownership & event history")),
            children: [
              for (final event in history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: FieldText(statusLabel(event['action'] as String)),
                  subtitle: FieldText(
                    '${event['actor_id']} · ${event['received_at']}\n${event['details']}',
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: busy || historyOffset == 0
                        ? null
                        : () => historyPage(historyOffset - 50),
                    child: const FieldText(UiText("Previous history")),
                  ),
                  FieldText(
                    UiText("History page {0}", [historyOffset ~/ 50 + 1]),
                  ),
                  TextButton(
                    onPressed: busy || history.length < 50
                        ? null
                        : () => historyPage(historyOffset + 50),
                    child: const FieldText(UiText("Next history")),
                  ),
                ],
              ),
            ],
          ),
          TextButton(
            onPressed: () => setState(() {
              selected = null;
              slaughterCheck = null;
              history = [];
            }),
            child: const FieldText(UiText("Back to animals")),
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
          eyebrow: UiText("Animal registry"),
          title: UiText("An ID for life."),
          subtitle: UiText("Owners change. Animal numbers stay the same."),
        ),
        const SizedBox(height: 16),
        if (widget.configs.length > 1)
          DropdownButtonFormField<SpeciesConfig>(
            initialValue: config,
            decoration: const InputDecoration(
              label: FieldText(UiText("Species")),
            ),
            items: widget.configs
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: FieldText(speciesLabel(item.species.name)),
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
                  label: FieldText(UiText("Look up animal ID")),
                  hint: FieldText(
                    config.numberingExample == null
                        ? UiText("Enter the ID from the tag or ledger")
                        : UiText("e.g. {0} or an existing ID", [
                            config.numberingExample,
                          ]),
                  ),
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
                          setState(
                            () => message = UiText("Enter a valid animal ID"),
                          );
                          return;
                        }
                        open(id);
                      },
                icon: const Icon(Icons.search),
                label: const FieldText(
                  UiText("Check animal / slaughter record"),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy || config.numbering == null ? null : newAnimal,
                icon: const Icon(Icons.add),
                label: const FieldText(UiText("Register new animal")),
              ),
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final id = selected?['animal_id'] as String?;
                        await reload();
                        if (mounted && id != null && message == null) {
                          await open(id);
                        }
                      },
                icon: const Icon(Icons.refresh),
                label: const FieldText(UiText("Refresh registry")),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (busy) const LinearProgressIndicator(),
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: FieldText(
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
                FieldText(
                  UiText("{0} registry changes waiting for acknowledgement", [
                    pending.length,
                  ]),
                ),
                TextButton(
                  onPressed: busy ? null : retry,
                  child: const FieldText(
                    UiText("Retry pending registry changes"),
                  ),
                ),
              ],
            ),
          ),
        for (final issue in journal.issues)
          FieldText(issue, style: const TextStyle(color: FieldColors.red)),
        if (selected != null)
          detail()
        else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const FieldText(UiText("Include archived animals")),
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
          if (animals.isEmpty && !busy && message == null)
            const FieldCard(
              child: FieldText(
                UiText(
                  "No animals in this view. Connect to the backend to review the registry.",
                ),
              ),
            ),
          for (final animal in animals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FieldCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: FieldText(
                    animal['animal_id'] as String,
                    style: _numberStyle,
                  ),
                  subtitle: FieldText(
                    UiText('{0} · {1}', [
                      animal['owner']?['name'] ??
                          const UiText('Owner not recorded'),
                      statusLabel(animal['lifecycle'] as String),
                    ]),
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
                child: const FieldText(UiText("Previous animals")),
              ),
              FieldText(UiText("Page {0}", [offset ~/ 50 + 1])),
              TextButton(
                onPressed: busy || animals.length < 50
                    ? null
                    : () {
                        setState(() => offset += 50);
                        reload();
                      },
                child: const FieldText(UiText("Next animals")),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
