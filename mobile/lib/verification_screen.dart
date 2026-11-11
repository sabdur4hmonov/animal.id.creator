import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'field_store.dart';
import 'local_registration.dart';
import 'localization.dart';
import 'verification_codes.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({
    super.key,
    required this.store,
    required this.label,
    required this.species,
    this.registration,
  });
  final FieldStore store;
  final String label, species;
  final LocalRegistration? registration;
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  late final service = VerificationCodes(
    widget.store,
    widget.label,
    widget.species,
    widget.registration,
  );
  List<Map<String, dynamic>> codes = [];
  bool busy = false, online = false, loading = true;
  UiText? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      codes = await service.saved();
    } catch (e) {
      error = userError(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || loading) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      codes = await service.refresh();
      online = true;
    } catch (e) {
      online = false;
      error = userError(e);
      await _load();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _revoke(Map code) async {
    var reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const FieldText(UiText('Revoke verification code')),
        content: TextField(
          maxLength: 1000,
          onChanged: (v) => reason = v,
          decoration: InputDecoration(
            labelText: const UiText('Reason').resolve(dialog),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const FieldText(UiText('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const FieldText(UiText('Revoke code')),
          ),
        ],
      ),
    );
    if (confirmed == true && reason.trim().isNotEmpty) {
      await _run(() => service.revoke(code['code_id'] as String, reason));
    }
  }

  Future<void> _share(Map code) async {
    final render = context.findRenderObject();
    final box = render is RenderBox ? render : null;
    final directory = await Directory.systemTemp.createTemp('chorvam_qr_');
    final file = await File(
      '${directory.path}/Chorvam-QR.png',
    ).writeAsBytes(base64Decode(code['qr_png_base64'] as String), flush: true);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: const UiText(
          'Registry record only, not a laboratory test. Check the QR online.',
        ).resolve(context),
        sharePositionOrigin: box == null
            ? const Rect.fromLTWH(0, 0, 1, 1)
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _shareOnly(Map code) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await _share(code);
    } catch (e) {
      error = userError(e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const FieldText(UiText('Slaughter verification QR'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy || loading) const LinearProgressIndicator(),
        const FieldText(
          UiText(
            'QR is available only after slaughter is recorded on the server. This is a registry record, not a laboratory test.',
          ),
        ),
        if (!online)
          const FieldText(
            UiText(
              'Saved copy. Connect to check whether the code is still active.',
            ),
          ),
        if (error != null) FieldText(error!),
        if (widget.registration?.configured != true)
          const FieldText(
            UiText('Connect and register this animal to manage its QR code.'),
          ),
        OutlinedButton(
          onPressed: busy || loading || widget.registration?.configured != true
              ? null
              : () => _run(() async {}),
          child: const FieldText(UiText('Refresh code status')),
        ),
        if (codes.every((c) => c['revoked'] == true))
          FilledButton(
            onPressed: busy || loading || widget.registration?.configured != true
                ? null
                : () => _run(service.issue),
            child: const FieldText(UiText('Create verification QR')),
          ),
        for (final code in codes)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (code['revoked'] == true)
                    const FieldText(UiText('Code revoked'))
                  else
                    Image.memory(
                      base64Decode(code['qr_png_base64'] as String),
                      height: 240,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  SelectableText(code['animal_id'] as String),
                  SelectableText(code['url'] as String),
                  if (code['revoked'] != true) ...[
                    OutlinedButton(
                      onPressed: busy ? null : () => _shareOnly(code),
                      child: const FieldText(UiText('Share QR')),
                    ),
                    TextButton(
                      onPressed: busy || widget.registration?.configured != true
                          ? null
                          : () => _revoke(code),
                      child: const FieldText(UiText('Revoke code')),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
