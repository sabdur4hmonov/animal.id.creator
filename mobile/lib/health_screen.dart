import 'package:flutter/material.dart';
import 'health_records.dart';
import 'field_store.dart';
import 'local_registration.dart';
import 'localization.dart';

class HealthHistoryScreen extends StatefulWidget {
  const HealthHistoryScreen({
    super.key,
    required this.store,
    required this.label,
    required this.config,
    this.registration,
  });
  final FieldStore store;
  final String label;
  final Map<String, dynamic> config;
  final LocalRegistration? registration;
  @override
  State<HealthHistoryScreen> createState() => _HealthHistoryScreenState();
}

class _HealthHistoryScreenState extends State<HealthHistoryScreen> {
  late final records = HealthRecords(widget.store, widget.config);
  List<Map<String, dynamic>> events = [];
  bool busy = false;
  UiText? error;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      events = await records.events(widget.label);
    } catch (e) {
      error = userError(e);
    }
    if (mounted) setState(() {});
  }

  Future<void> _add([Map? original]) async {
    var kind = original?['kind'] as String? ?? healthKinds.first;
    var date =
        original?['event_date'] as String? ??
        DateTime.now().toIso8601String().substring(0, 10);
    var description = original?['description'] as String? ?? '',
        veterinarian = original?['veterinarian_name'] as String? ?? '',
        notes = '';
    UiText? formError;
    var saving = false;
    final limits = widget.config['health_history'] as Map;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          title: FieldText(
            UiText(
              original == null ? 'Add health record' : 'Add correcting record',
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  isExpanded: true,
                  itemHeight: null,
                  items: [
                    for (var i = 0; i < healthKinds.length; i++)
                      DropdownMenuItem(
                        value: healthKinds[i],
                        child: FieldText(UiText(healthKindLabels[i])),
                      ),
                  ],
                  onChanged: (v) => kind = v!,
                ),
                TextFormField(
                  initialValue: date,
                  onChanged: (v) => date = v,
                  decoration: InputDecoration(
                    labelText: const UiText(
                      'Event date YYYY-MM-DD',
                    ).resolve(dialog),
                  ),
                ),
                TextFormField(
                  initialValue: description,
                  maxLength: limits['description_max_length'] as int,
                  onChanged: (v) => description = v,
                  decoration: InputDecoration(
                    labelText: const UiText('Description').resolve(dialog),
                  ),
                ),
                TextFormField(
                  initialValue: veterinarian,
                  maxLength: limits['veterinarian_max_length'] as int,
                  onChanged: (v) => veterinarian = v,
                  decoration: InputDecoration(
                    labelText: const UiText(
                      'Veterinarian name (optional)',
                    ).resolve(dialog),
                  ),
                ),
                TextField(
                  maxLength: limits['notes_max_length'] as int,
                  onChanged: (v) => notes = v,
                  decoration: InputDecoration(
                    labelText: const UiText('Notes').resolve(dialog),
                  ),
                ),
                if (formError != null) FieldText(formError!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialog),
              child: const FieldText(UiText('Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                if (saving) return;
                refresh(() => saving = true);
                try {
                  await records.add(
                    widget.label,
                    kind,
                    date.trim(),
                    description,
                    veterinarian,
                    notes,
                    correctionOf: original?['key'] as String?,
                  );
                  if (dialog.mounted) Navigator.pop(dialog, true);
                } catch (e) {
                  if (dialog.mounted) {
                    refresh(() {
                      saving = false;
                      formError = const UiText(
                        'Check the date and required description.',
                      );
                    });
                  }
                }
              },
              child: const FieldText(UiText('Save record')),
            ),
          ],
        ),
      ),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _sync() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await records.sync(widget.label, widget.registration!);
    } catch (e) {
      error = userError(e);
    }
    if (mounted) {
      setState(() => busy = false);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const FieldText(UiText('Health and vaccinations'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const FieldText(
          UiText(
            'Reported history, not a diagnosis. Corrections keep every earlier record.',
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) FieldText(error!),
        FilledButton(
          onPressed: busy ? null : () => _add(),
          child: const FieldText(UiText('Add health record')),
        ),
        if (widget.registration != null)
          OutlinedButton(
            onPressed: busy || !widget.registration!.configured ? null : _sync,
            child: const FieldText(UiText('Sync health history')),
          ),
        for (final e in events.reversed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldText(
                    UiText(
                      healthKindLabels[healthKinds.indexOf(
                        e['kind'] as String,
                      )],
                    ),
                  ),
                  Text(e['event_date'] as String),
                  Text(e['description'] as String),
                  if (e['veterinarian_name'] != null)
                    Text(e['veterinarian_name'] as String),
                  if ((e['notes'] as String).isNotEmpty)
                    Text(e['notes'] as String),
                  const FieldText(UiText('Operator record')),
                  if (e['correction_of'] != null)
                    const FieldText(UiText('Correcting record')),
                  if (!events.any((r) => r['correction_of'] == e['key']))
                    TextButton(
                      onPressed: busy ? null : () => _add(e),
                      child: const FieldText(UiText('Add correcting record')),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
