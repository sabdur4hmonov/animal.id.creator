import 'package:flutter/material.dart';
import 'ar_math.dart';
import 'ar_records.dart';
import 'ar_screen.dart';
import 'local_profiles.dart';
import 'localization.dart';
import 'side_photo_link.dart';
import 'local_registration.dart';
import 'registration_views.dart';
import 'health_screen.dart';
import 'ownership_screen.dart';

String fieldDay(Object? value) {
  final s = value?.toString() ?? '';
  return s.length >= 10 ? s.substring(0, 10) : s;
}

UiText fieldMode(Object? mode) => UiText(switch (mode) {
  'snapshot' => 'Snapshot: left + right, optional front',
  'fast' => 'Fast: six points, estimated girth',
  'contour' => 'Detailed: closed 3D contour',
  _ => 'Measurement mode',
});
List<String> formulaNames = ['Trukhanovsky', 'Schoorl'];
List<String> formulaKeys = ['trukhanovsky', 'schoorl'];
List<Widget> weightLines(Map set) => [
  for (var i = 0; i < formulaKeys.length; i++)
    FieldText(
      UiText('{0}: {1} kg', [
        formulaNames[i],
        Amount.parse(set['weights_kg'][formulaKeys[i]]).text,
      ]),
    ),
];

class ProfileThumbnail extends StatelessWidget {
  const ProfileThumbnail({
    super.key,
    required this.cache,
    this.scan,
    this.size = 72,
  });
  final ProfileThumbnails cache;
  final Map? scan;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FutureBuilder(
        future: cache.get(scan),
        builder: (context, data) => data.data == null
            ? const ColoredBox(
                color: Color(0xffe8efe9),
                child: Icon(Icons.photo_outlined),
              )
            : Image.file(
                data.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
      ),
    ),
  );
}

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.profile,
    required this.cache,
    this.onTap,
  });
  final LocalProfile profile;
  final ProfileThumbnails cache;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final set = profile.latestEstimate;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileThumbnail(cache: cache, scan: profile.latestPhoto),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.id,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (profile.tag.isNotEmpty) Text(profile.tag),
                    if (set != null) ...[
                      FieldText(
                        UiText('Latest approximate weight: {0} kg · {1}', [
                          Amount.parse(set['weights_kg']['trukhanovsky']).text,
                          fieldDay(set['created_at']),
                        ]),
                      ),
                    ] else
                      const FieldText(UiText('No saved weight yet')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileListScreen extends StatefulWidget {
  const ProfileListScreen({
    super.key,
    required this.catalog,
    required this.cache,
    this.pick = false,
    this.open,
    this.scan,
  });
  final ProfileCatalog catalog;
  final ProfileThumbnails cache;
  final bool pick;
  final Future<void> Function(String)? open;
  final Future<void> Function()? scan;
  @override
  State<ProfileListScreen> createState() => _ProfileListScreenState();
}

class _ProfileListScreenState extends State<ProfileListScreen> {
  String search = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: FieldText(
        UiText(widget.pick ? 'Choose the matching animal' : 'My cattle'),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.pick)
          const FieldText(
            UiText(
              'Automatic recognition is a later phase. Confirm the animal yourself.',
            ),
          ),
        TextField(
          onChanged: (v) => setState(() => search = v),
          decoration: InputDecoration(
            labelText: const UiText(
              'Search ID, tag or nickname',
            ).resolve(context),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        if (widget.scan != null)
          OutlinedButton(
            onPressed: () async {
              await widget.scan!();
              if (mounted) setState(() {});
            },
            child: const FieldText(UiText('Scan animal')),
          ),
        if (widget.catalog.search(search).isEmpty)
          const FieldText(UiText('No animals found')),
        for (final p in widget.catalog.search(search))
          ProfileCard(
            profile: p,
            cache: widget.cache,
            onTap: () async {
              if (widget.pick) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: const FieldText(UiText('Confirm animal')),
                    content: FieldText(
                      UiText('Save this photo to {0}?', [p.id]),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const FieldText(UiText('Cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const FieldText(UiText('Yes, this animal')),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) Navigator.pop(context, p.id);
              } else {
                await widget.open?.call(p.id);
                if (mounted) setState(() {});
              }
            },
          ),
      ],
    ),
  );
}

class AnimalProfileScreen extends StatefulWidget {
  const AnimalProfileScreen({
    super.key,
    required this.id,
    required this.catalog,
    required this.cache,
    required this.config,
    required this.newPhoto,
    this.sidePhoto,
    this.registration,
  });
  final String id;
  final ProfileCatalog catalog;
  final ProfileThumbnails cache;
  final Map<String, dynamic> config;
  final Future<void> Function(LocalProfile) newPhoto;
  final Future<void> Function(LocalProfile, String)? sidePhoto;
  final LocalRegistration? registration;
  @override
  State<AnimalProfileScreen> createState() => _AnimalProfileScreenState();
}

class _AnimalProfileScreenState extends State<AnimalProfileScreen> {
  LocalProfile get profile => widget.catalog.get(widget.id)!;
  bool busy = false;
  String? error;
  Future<void> _update(Future<void> Function() run) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await run();
      await widget.catalog.refresh();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _weigh() async {
    var kg = '', date = fieldDay(DateTime.now().toIso8601String());
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const FieldText(UiText('True scale weight (kg)')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (v) => kg = v,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: const UiText(
                    'True scale weight (kg)',
                  ).resolve(context),
                ),
              ),
              TextFormField(
                initialValue: date,
                onChanged: (v) => date = v,
                decoration: InputDecoration(
                  labelText: const UiText(
                    'Weighing date YYYY-MM-DD',
                  ).resolve(context),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const FieldText(UiText('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, (kg.trim(), date.trim())),
            child: const FieldText(UiText('Save true weighing')),
          ),
        ],
      ),
    );
    if (values == null || !mounted) return;
    await _update(() async {
      final now = DateTime.now(), observed = fieldDate(values.$2, now);
      final kg = Amount.parse(values.$1);
      if (kg.number <= 0 || kg.number > 5000) {
        throw const FormatException('Invalid scale weight');
      }
      final ar = profile.latestEstimate,
          records = ArRecords(widget.catalog.store);
      final measured = ar == null
          ? null
          : DateTime.parse(ar['created_at'] as String);
      if (ar != null &&
          measured != null &&
          observed
                  .difference(
                    DateTime.utc(measured.year, measured.month, measured.day),
                  )
                  .inDays
                  .abs() <=
              ar['config_snapshot']['ar']['max_scale_weight_age_days']) {
        await records.weighing(ar, values.$1, values.$2);
      } else {
        await records.save('scale_observation', {
          'label': profile.id,
          'species': profile.animal['species'],
          'scale_kg': values.$1,
          'weighed_date': values.$2,
          'set_key': null,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = profile,
        latest = p.latestEstimate,
        scale = p.latestScale,
        price = p.prices.firstOrNull,
        photo = p.latestPhoto;
    return Scaffold(
      appBar: AppBar(title: const FieldText(UiText('Animal profile'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (photo != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  widget.catalog.photo(photo),
                  fit: BoxFit.cover,
                  cacheWidth: 960,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          SelectableText(
            p.id,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (p.tag.isNotEmpty)
            Text(p.tag, style: Theme.of(context).textTheme.titleMedium),
          if ((p.animal['notes'] as String? ?? '').isNotEmpty)
            Text(p.animal['notes'] as String),
          FieldText(
            UiText('Created {0} · operator {1}', [
              fieldDay(p.animal['created_at']),
              p.animal['operator_id'],
            ]),
          ),
          if (busy) const LinearProgressIndicator(),
          if (widget.registration != null)
            RegistrationPanel(service: widget.registration!, profile: p),
          if (error != null) FieldText(UiText('Action failed: {0}', [error])),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: busy
                    ? null
                    : () => _update(() => widget.newPhoto(p)),
                child: const FieldText(UiText('New photo')),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _update(
                        () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ArScreen(
                              store: widget.catalog.store,
                              animal: p.animal,
                              config: widget.config,
                            ),
                          ),
                        ),
                      ),
                child: const FieldText(UiText('AR measurement')),
              ),
              OutlinedButton(
                onPressed: busy ? null : _weigh,
                child: const FieldText(UiText('Scale weight')),
              ),
            ],
          ),
          const Divider(),
          const FieldText(UiText('Latest weight')),
          if (latest != null) ...[
            const FieldText(UiText('Approximate, uncalibrated weight')),
            FieldText(
              UiText('{0} · {1}', [
                fieldMode(latest['mode']),
                fieldDay(latest['created_at']),
              ]),
            ),
            ...weightLines(latest),
            if (price != null)
              for (var i = 0; i < formulaKeys.length; i++)
                _valuation(latest, price, i),
          ] else
            const FieldText(UiText('No saved weight yet')),
          if (scale != null)
            FieldText(
              UiText('Scale weight: {0} kg · {1}', [
                scale['scale_kg'],
                scale['weighed_date'],
              ]),
            ),
          const Divider(),
          const FieldText(UiText('All muzzle photos')),
          for (final s in p.photos)
            ListTile(
              leading: ProfileThumbnail(cache: widget.cache, scan: s, size: 48),
              title: Text(fieldDay(s['metadata']['timestamp'])),
              subtitle: FieldText(UiText(photoViewLabel(s['view'] as String))),
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialog) => Dialog(
                  child: Image.file(
                    widget.catalog.photo(s),
                    fit: BoxFit.contain,
                    cacheWidth: 960,
                  ),
                ),
              ),
            ),
          const Divider(),
          const FieldText(UiText('Side photos for weight data')),
          const FieldText(
            UiText(
              'Collected for a future weight model. No weight is calculated from this photo.',
            ),
          ),
          if (widget.sidePhoto != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final side in ['left', 'right'])
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => _update(() => widget.sidePhoto!(p, side)),
                    child: FieldText(
                      UiText(
                        side == 'left' ? 'Left body photo' : 'Right body photo',
                      ),
                    ),
                  ),
              ],
            ),
          for (final s in p.sidePhotos) _sidePhoto(s),
          const Divider(),
          const FieldText(UiText('Measurement history')),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => OwnershipScreen(
                        store: widget.catalog.store,
                        label: p.id,
                        config: widget.config,
                        registration: widget.registration,
                      ),
                    ),
                  ),
            child: const FieldText(UiText('Ownership history')),
          ),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => HealthHistoryScreen(
                        store: widget.catalog.store,
                        label: p.id,
                        config: widget.config,
                        registration: widget.registration,
                      ),
                    ),
                  ),
            child: const FieldText(UiText('Health and vaccinations')),
          ),
          for (final m in p.measurements)
            if (m['record_type'] == 'repeat_set')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FieldText(
                        UiText('{0} · {1}', [
                          fieldMode(m['mode']),
                          fieldDay(m['created_at']),
                        ]),
                      ),
                      if (m['valid'] == true)
                        ...weightLines(m)
                      else
                        const FieldText(
                          UiText('Measurement rejected; repeat it'),
                        ),
                    ],
                  ),
                ),
              )
            else if ({
              'weighing',
              'scale_observation',
            }.contains(m['record_type']))
              FieldText(
                UiText('Scale weight: {0} kg · {1}', [
                  m['scale_kg'],
                  m['weighed_date'],
                ]),
              ),
          const Divider(),
          const FieldText(UiText('Price history')),
          for (final r in p.prices)
            FieldText(
              UiText('{0} UZS/kg · {1} · {2}', [
                r['meat_uzs_per_kg'],
                r['effective_date'],
                r['source'],
              ]),
            ),
        ],
      ),
    );
  }

  Widget _valuation(Map set, Map price, int formula) {
    final q = valuationRange(
      Amount.parse(set['weights_kg'][formulaKeys[formula]]),
      set['config_snapshot'] as Map,
      price,
    );
    return FieldText(
      UiText('{0}: {1}–{2} UZS at the latest price', [
        formulaNames[formula],
        q['uzs_min'],
        q['uzs_max'],
      ]),
    );
  }

  Widget _sidePhoto(Map s) {
    final scale = nearestSideScale(s, profile.measurements);
    return ListTile(
      leading: ProfileThumbnail(cache: widget.cache, scan: s, size: 48),
      title: FieldText(
        UiText(s['side'] == 'left' ? 'Left body photo' : 'Right body photo'),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fieldDay(s['captured_at'])),
          if (scale != null)
            FieldText(
              UiText('Scale weight: {0} kg · {1}', [
                scale['scale_kg'],
                scale['weighed_date'],
              ]),
            )
          else
            const FieldText(
              UiText('No nearby scale weight. Add kg and weighing date.'),
            ),
        ],
      ),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: Image.file(
            widget.catalog.photo(s),
            cacheWidth: 960,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

String photoViewLabel(String view) => switch (view) {
  'front1' => 'Front 1/2',
  'front2' => 'Front 2/2',
  'left15_1' => 'Left 15° 1/2',
  'left15_2' => 'Left 15° 2/2',
  'right15_1' => 'Right 15° 1/2',
  'right15_2' => 'Right 15° 2/2',
  _ => view,
};
