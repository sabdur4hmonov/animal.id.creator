import 'package:flutter/material.dart';
import 'advisory_scan.dart';
import 'bundled_configs.dart';
import 'capture_environment.dart';
import 'capture_screen.dart';
import 'field_store.dart';
import 'field_widgets.dart';
import 'local_profiles.dart';
import 'localization.dart';
import 'muzzle_scan_camera.dart';
import 'profile_views.dart';
import 'species.dart';
import 'side_photos.dart';

class FieldHome extends StatefulWidget {
  const FieldHome({
    super.key,
    required this.environment,
    this.engine = const AdvisoryEngine(),
  });
  final CaptureEnvironment environment;
  final AdvisoryEngine engine;
  @override
  State<FieldHome> createState() => _FieldHomeState();
}

class _FieldHomeState extends State<FieldHome> {
  FieldScanWorkflow? flow;
  ProfileThumbnails? thumbnails;
  SpeciesConfig? species;
  bool busy = true;
  UiText? notice;
  Map<String, dynamic>? pendingDraft;
  CaptureEnvironment get env => widget.environment;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final queue = await env.openQueue(), store = FieldStore(queue.root);
      await store.initialize();
      species = (await bundledSpecies()).first;
      final config = await bundledConfig(
        'business_configs-${species!.species.name}.yaml',
      );
      final catalog = ProfileCatalog(store);
      await catalog.refresh();
      flow = FieldScanWorkflow(
        store,
        queue,
        catalog,
        env,
        config,
        engine: widget.engine,
      );
      thumbnails = ProfileThumbnails(
        catalog,
        flow!.rules['thumbnail_max_side'] as int,
      );
      pendingDraft = (await flow!.pending()).lastOrNull;
    } catch (e) {
      notice = UiText('Action failed: {0}', [userError(e)]);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<bool> _operator() async {
    final store = flow!.store;
    if (validFieldOperator(store.operatorId)) return true;
    final id = await fieldOperatorDialog(context, store.operatorId);
    if (id == null) return false;
    await store.saveOperator(id);
    return true;
  }

  Future<void> _scan({
    LocalProfile? pinned,
    Map<String, dynamic>? resume,
  }) async {
    if (flow == null || busy) return;
    final wf = flow!;
    String? openId;
    Map<String, dynamic>? nextBurstFrame;
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      if (!await _operator() || !mounted) return;
      final draft =
          resume ??
          await Navigator.of(context).push<Map<String, dynamic>>(
            MaterialPageRoute(
              builder: (_) => MuzzleScanCamera(
                workflow: wf,
                species: species!,
                profileId: pinned?.id,
              ),
            ),
          );
      if (draft == null || !mounted) {
        if (mounted) pendingDraft = (await wf.pending()).lastOrNull;
        return;
      }
      pendingDraft = draft;
      final profileId = draft['profile_id'] as String?;
      final target = profileId == null ? null : wf.catalog.get(profileId);
      if (profileId != null && target == null) {
        throw const FormatException('Saved photo target is missing');
      }
      final evaluation = await wf.evaluate(
            draft,
            knownProfile: target != null && draft['capture_group'] == null,
          ),
          prior = await wf.priorDecision(draft);
      final reservation = prior == null && target == null
          ? (await wf.store.records('animal'))
                .where((a) => a['registration_scan_key'] == draft['scan_key'])
                .firstOrNull
          : null;
      if (!mounted) return;
      String action;
      Map<String, dynamic>? animal;
      String? session;
      if (prior != null) {
        animal = wf.catalog.get(prior['label'] as String)?.animal;
        action = prior['action'] as String;
        if (animal == null) {
          throw const FormatException('Previously assigned animal missing');
        }
      } else if (reservation != null) {
        animal = reservation;
        action = 'new';
      } else if (target != null) {
        animal = target.animal;
        action = 'profile_photo';
        final previous = target.latestPhoto?['session'] as String?;
        if (previous?.startsWith(fieldDay(env.now().toIso8601String())) ==
            true) {
          session = previous;
        }
      } else {
        final warnings = (evaluation['candidates'] as List)
            .where((c) => c['warning'] == true)
            .toList();
        String? choice = 'new';
        if (warnings.isNotEmpty ||
            evaluation['status'] == 'unavailable' ||
            evaluation['status'] == 'partial') {
          choice = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => _AdvisoryReview(
                wf: wf,
                draft: draft,
                evaluation: evaluation,
                cache: thumbnails!,
              ),
            ),
          );
        }
        if (choice == null || !mounted) return;
        if (choice == 'new') {
          animal = await fieldAnimalDialog(
            context,
            wf.store,
            env.now(),
            registrationScanKey: draft['scan_key'] as String,
            allowExisting: wf.catalog.profiles.isNotEmpty,
          );
          if (!mounted) return;
          if (animal?['pick_existing'] == true) {
            final selected = await _pick();
            animal = selected == null ? null : wf.catalog.get(selected)?.animal;
            action = 'existing';
          } else {
            action = 'new';
          }
        } else if (choice == 'pick') {
          final selected = await _pick();
          animal = selected == null ? null : wf.catalog.get(selected)?.animal;
          action = 'existing';
        } else {
          animal = wf.catalog.get(choice)?.animal;
          action = 'existing';
        }
      }
      if (animal == null) return;
      final saved = await wf.attach(
        draft,
        evaluation,
        animal,
        action: action,
        session: session,
      );
      pendingDraft = (await wf.pending()).lastOrNull;
      if (draft['capture_group'] != null) {
        nextBurstFrame = (await wf.pending())
            .where((r) => r['capture_group'] == draft['capture_group'])
            .firstOrNull;
      }
      if (saved.galleryWarning) {
        notice = const UiText(
          'Original saved. Gallery copy failed; check permission and storage. {0}',
          [''],
        );
      }
      if (pinned == null) openId = saved.label;
    } catch (e) {
      notice = UiText('Action failed: {0}', [userError(e)]);
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (nextBurstFrame != null && mounted) {
      // Every frame runs the existing candidate/new-ID confirmation independently.
      await _scan(resume: nextBurstFrame);
    } else if (openId != null && mounted) {
      await _profile(openId);
    }
  }

  Future<String?> _pick() => Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => ProfileListScreen(
        catalog: flow!.catalog,
        cache: thumbnails!,
        pick: true,
      ),
    ),
  );
  Future<void> _profile(String id) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => AnimalProfileScreen(
        id: id,
        catalog: flow!.catalog,
        cache: thumbnails!,
        config: flow!.config,
        newPhoto: (p) => _scan(pinned: p),
        sidePhoto: (p, side) => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SidePhotoCamera(
              store: flow!.store,
              animal: p.animal,
              side: side,
              config: flow!.config,
              species: species!,
              environment: env,
            ),
          ),
        ),
      ),
    ),
  );
  Future<void> _list() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ProfileListScreen(
        catalog: flow!.catalog,
        cache: thumbnails!,
        open: _profile,
        scan: () => _scan(),
      ),
    ),
  );
  Future<void> _legacy() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CaptureScreen(environment: env)),
    );
    if (!mounted) return;
    setState(() => busy = true);
    await _load();
  }

  Future<void> _tools() async {
    final wf = flow;
    if (wf == null) {
      await _legacy();
      return;
    }
    final report = advisoryReport(
      await wf.store.records(
        'measurement',
        strict: false,
        eventTypes: {'match_decision'},
      ),
    );
    if (!mounted) return;
    final legacy = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (page) => Scaffold(
          appBar: AppBar(title: const FieldText(UiText('Tools'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FieldText(UiText('Offline operator: {0}', [wf.store.operatorId])),
              const FieldText(UiText('Advisory scan review')),
              FieldText(
                UiText('Repeat scans with correct warning: {0}/{1}', [
                  report['repeat_found'],
                  report['repeat_total'],
                ]),
              ),
              FieldText(
                UiText('Repeat scans missed: {0}/{1}', [
                  report['repeat_missed'],
                  report['repeat_total'],
                ]),
              ),
              FieldText(
                UiText('Warnings on confirmed new animals: {0}/{1}', [
                  report['new_warned'],
                  report['new_total'],
                ]),
              ),
              const FieldText(
                UiText(
                  'Counts use your confirmations; they are not accuracy guarantees.',
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(page, true),
                child: const FieldText(
                  UiText('Collection, language and ZIP backup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (legacy == true && mounted) await _legacy();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chorvam')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.document_scanner_outlined, size: 80),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy || flow == null ? null : () => _scan(),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(80)),
          child: const FieldText(UiText('Scan animal')),
        ),
        if (busy) const LinearProgressIndicator(),
        if (notice != null) FieldText(notice!),
        if (pendingDraft != null)
          OutlinedButton(
            onPressed: busy ? null : () => _scan(resume: pendingDraft),
            child: const FieldText(UiText('Continue saved scan')),
          ),
        OutlinedButton(
          onPressed: busy || flow == null ? null : _list,
          child: const FieldText(UiText('My cattle')),
        ),
        TextButton(
          onPressed: busy ? null : _tools,
          child: const FieldText(UiText('Tools')),
        ),
        const FieldText(
          UiText('Photos and weights stay with the animal ID on this phone.'),
        ),
      ],
    ),
  );
}

class _AdvisoryReview extends StatelessWidget {
  const _AdvisoryReview({
    required this.wf,
    required this.draft,
    required this.evaluation,
    required this.cache,
  });
  final FieldScanWorkflow wf;
  final Map draft, evaluation;
  final ProfileThumbnails cache;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const FieldText(UiText('Check for repeats'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const FieldText(UiText('Experimental similarity signal')),
        const FieldText(
          UiText(
            'Automatic recognition is a later phase. Confirm the animal yourself.',
          ),
        ),
        if ({'unavailable', 'partial'}.contains(evaluation['status']))
          const FieldText(
            UiText(
              'Some comparisons were unavailable. Check the saved list yourself.',
            ),
          ),
        for (final c in (evaluation['candidates'] as List).where(
          (r) => r['warning'] == true,
        ))
          if (wf.catalog.get(c['animal_id'] as String) case final profile?)
            _candidate(context, profile, c as Map),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, 'pick'),
          child: const FieldText(UiText('Choose existing animal')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'new'),
          child: const FieldText(UiText('No, a different animal')),
        ),
      ],
    ),
  );
  Widget _candidate(BuildContext context, LocalProfile p, Map c) {
    final stored =
        p.photos.where((s) => s['request_key'] == c['photo_key']).firstOrNull ??
        p.latestPhoto;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldText(
              UiText('This looks like {0}. Is it the same animal?', [p.id]),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Image.file(
                          wf.original(draft),
                          fit: BoxFit.cover,
                          cacheWidth: 320,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                      const FieldText(UiText('New photo')),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: stored == null
                            ? const Icon(Icons.photo_outlined)
                            : Image.file(
                                wf.catalog.photo(stored),
                                fit: BoxFit.cover,
                                cacheWidth: 320,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                      ),
                      const FieldText(UiText('Saved photo')),
                    ],
                  ),
                ),
              ],
            ),
            ProfileCard(profile: p, cache: cache),
            FilledButton(
              onPressed: () => Navigator.pop(context, p.id),
              child: const FieldText(UiText('Yes, this animal')),
            ),
          ],
        ),
      ),
    );
  }
}
