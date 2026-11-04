import 'package:flutter/material.dart';
import 'field_store.dart';
import 'localization.dart';

Future<Map<String, dynamic>?> fieldAnimalDialog(
  BuildContext context,
  FieldStore store,
  DateTime now,
) async {
  var tag = '', notes = '';
  String? error;
  bool saving = false;
  return await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) => PopScope(
        canPop: !saving,
        child: AlertDialog(
          title: const FieldText(UiText('Temporary animal')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FieldText(
                  UiText(
                    'Temporary label only. Not registered on the server; no automatic registration or sync.',
                  ),
                ),
                TextField(
                  onChanged: (v) => tag = v,
                  enabled: !saving,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: const UiText(
                      'Tag / nickname (optional)',
                    ).resolve(context),
                  ),
                ),
                TextField(
                  onChanged: (v) => notes = v,
                  enabled: !saving,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: const UiText(
                      'Field notes (optional)',
                    ).resolve(context),
                  ),
                ),
                if (error != null) Text(error!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const FieldText(UiText('Cancel')),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      refresh(() => saving = true);
                      try {
                        final animal = await store.newAnimal(
                          tag.trim(),
                          notes.trim(),
                          now,
                        );
                        if (context.mounted) Navigator.pop(context, animal);
                      } catch (e) {
                        if (context.mounted) {
                          refresh(() {
                            saving = false;
                            error = userError(e).resolve(context);
                          });
                        }
                      }
                    },
              child: const FieldText(UiText('Create temporary label')),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> fieldOperatorDialog(
  BuildContext context,
  String initial,
) async {
  var value = initial;
  final form = GlobalKey<FormState>();
  return await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const FieldText(UiText('Offline operator ID')),
      content: Form(
        key: form,
        child: TextFormField(
          initialValue: initial,
          onChanged: (v) => value = v,
          autocorrect: false,
          decoration: InputDecoration(
            helperMaxLines: 4,
            helperText: const UiText(
              'Use a stable ASCII operator ID. Local capture needs no API token; uploads still require matching credentials.',
            ).resolve(context),
          ),
          validator: (v) => validFieldOperator(v?.trim() ?? '')
              ? null
              : const UiText(
                  'Use 1–64 letters, digits, underscores or hyphens',
                ).resolve(context),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const FieldText(UiText('Cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, value.trim());
            }
          },
          child: const FieldText(UiText('Save operator')),
        ),
      ],
    ),
  );
}
