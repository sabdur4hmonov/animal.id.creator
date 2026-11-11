import 'package:flutter/material.dart';
import 'field_store.dart';
import 'local_registration.dart';
import 'localization.dart';
import 'ownership_records.dart';

class OwnershipScreen extends StatefulWidget {
  const OwnershipScreen({
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
  State<OwnershipScreen> createState() => _OwnershipScreenState();
}

class _OwnershipScreenState extends State<OwnershipScreen> {
  late final records = OwnershipRecords(
    widget.store,
    widget.config,
    widget.registration,
  );
  List<Map<String, dynamic>> events = [];
  Map? owner;
  bool busy = false;
  UiText? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      events = await records.events(widget.label);
      owner = await records.currentOwner(widget.label);
    } catch (e) {
      error = userError(e);
    }
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final values = {
      'owner_id': '',
      'name': '',
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'price': '',
      'notes': '',
    };
    UiText? formError;
    var saving = false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => AlertDialog(
          scrollable: true,
          title: const FieldText(UiText('Sold / owner changed')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in [
                  ('owner_id', 'New owner reference', 64),
                  ('name', 'New owner name', 120),
                  ('date', 'Event date YYYY-MM-DD', 10),
                  ('price', 'Sale price, whole UZS (optional)', 16),
                  (
                    'notes',
                    'Transfer notes (required)',
                    widget.config['ownership_history']['notes_max_length']
                        as int,
                  ),
                ])
                  TextFormField(
                    initialValue: values[field.$1],
                    enabled: !saving,
                    maxLength: field.$3,
                    onChanged: (v) => values[field.$1] = v,
                    keyboardType: field.$1 == 'price'
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: UiText(field.$2).resolve(dialog),
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
                    values['owner_id']!,
                    values['name']!,
                    values['date']!.trim(),
                    values['price']!,
                    values['notes']!,
                  );
                  if (dialog.mounted) Navigator.pop(dialog, true);
                } catch (e) {
                  if (dialog.mounted) {
                    refresh(() {
                      saving = false;
                      formError = const UiText(
                        'Check the owner, date, notes and whole-sum price.',
                      );
                    });
                  }
                }
              },
              child: const FieldText(UiText('Save ownership report')),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) await _load();
  }

  Future<void> _sync() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await records.sync(widget.label);
    } catch (e) {
      error = userError(e);
    }
    if (mounted) {
      setState(() => busy = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const FieldText(UiText('Ownership history'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const FieldText(
          UiText(
            'Operator-reported ownership, not verified legal title or payment.',
          ),
        ),
        if (owner != null) Text('${owner!['owner_id']} · ${owner!['name']}'),
        if (error != null) FieldText(error!),
        if (busy) const LinearProgressIndicator(),
        FilledButton(
          onPressed: busy ? null : _add,
          child: const FieldText(UiText('Sold / owner changed')),
        ),
        if (widget.registration != null)
          OutlinedButton(
            onPressed: busy || !widget.registration!.configured ? null : _sync,
            child: const FieldText(UiText('Sync ownership history')),
          ),
        for (final e in events.reversed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${e['event_date']} · ${e['owner']['owner_id']}'),
                  Text(e['owner']['name'] as String),
                  if (e['price_uzs'] != null)
                    FieldText(UiText('{0} UZS', [e['price_uzs']])),
                  Text(e['notes'] as String),
                  const FieldText(UiText('Operator record')),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
