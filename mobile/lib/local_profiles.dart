import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'field_store.dart';

String normalizeFieldTag(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'\s+'), '');

class LocalProfile {
  LocalProfile(this.animal, this.photos, this.measurements, this.prices);
  final Map<String, dynamic> animal;
  final List<Map<String, dynamic>> photos, measurements, prices;
  String get id => animal['label'] as String;
  String get tag => animal['tag'] as String? ?? '';
  Map<String, dynamic>? get latestPhoto => photos.firstOrNull;
  Iterable<Map<String, dynamic>> get estimates => measurements.where(
    (e) => e['record_type'] == 'repeat_set' && e['valid'] == true,
  );
  Map<String, dynamic>? get latestEstimate => estimates.firstOrNull;
  Map<String, dynamic>? get latestScale => measurements
      .where(
        (e) => {'weighing', 'scale_observation'}.contains(e['record_type']),
      )
      .firstOrNull;
  String get activity => [
    animal['created_at'],
    latestPhoto?['metadata']?['timestamp'],
    measurements.firstOrNull?['created_at'],
  ].whereType<String>().reduce((a, b) => a.compareTo(b) > 0 ? a : b);
}

class ProfileCatalog {
  ProfileCatalog(this.store);
  final FieldStore store;
  List<LocalProfile> profiles = [];

  Future<void> refresh() async {
    final rows = await Future.wait([
      store.records('animal'),
      store.records('scan', strict: false),
      store.records(
        'measurement',
        strict: false,
        eventTypes: {
          'repeat_set',
          'weighing',
          'scale_observation',
          'valuation',
        },
      ),
      store.records('price', strict: false),
    ]);
    final photos = <String, List<Map<String, dynamic>>>{};
    final measures = <String, List<Map<String, dynamic>>>{};
    for (final r in rows[1].reversed) {
      if (r['provisional'] == true && r['label'] is String && _safePhoto(r)) {
        (photos[r['label'] as String] ??= []).add(r);
      }
    }
    for (final scans in photos.values) {
      scans.sort((a, b) {
        final newest = _captureTime(b).compareTo(_captureTime(a));
        return newest == 0
            ? (b['request_key'] as String).compareTo(a['request_key'] as String)
            : newest;
      });
    }
    for (final r in rows[2].reversed) {
      if (r['label'] is String) {
        (measures[r['label'] as String] ??= []).add(r);
      }
    }
    final prices = rows[3]
      ..sort((a, b) => (b['revision'] as int).compareTo(a['revision'] as int));
    profiles =
        [
          for (final a in rows[0])
            LocalProfile(
              a,
              photos[a['label']] ?? [],
              measures[a['label']] ?? [],
              prices.where((p) => p['species'] == a['species']).toList(),
            ),
        ]..sort((a, b) {
          final cmp = b.activity.compareTo(a.activity);
          return cmp == 0 ? a.id.compareTo(b.id) : cmp;
        });
  }

  bool _safePhoto(Map r) =>
      r['file_path'] is String &&
      RegExp(r'^[a-f0-9]{32}\.jpg$').hasMatch(r['file_path'] as String) &&
      r['sha256'] is String &&
      RegExp(r'^[a-f0-9]{64}$').hasMatch(r['sha256'] as String);
  String _captureTime(Map r) =>
      (r['metadata'] as Map?)?['timestamp'] as String? ?? '';
  LocalProfile? get(String id) => profiles.where((p) => p.id == id).firstOrNull;
  List<LocalProfile> search(String text) {
    final query = normalizeFieldTag(text);
    return profiles
        .where(
          (p) =>
              normalizeFieldTag(p.id).contains(query) ||
              normalizeFieldTag(p.tag).contains(query),
        )
        .toList();
  }

  List<LocalProfile> duplicateTag(String tag) {
    final key = normalizeFieldTag(tag);
    return key.isEmpty
        ? []
        : profiles.where((p) => normalizeFieldTag(p.tag) == key).toList();
  }

  File photo(Map scan) {
    if (!_safePhoto(scan)) {
      throw const FormatException('Unsafe photo reference');
    }
    return File('${store.root.path}/${scan['file_path']}');
  }

  List<Map<String, dynamic>> references(String species) => [
    for (final p in profiles.where((p) => p.animal['species'] == species))
      for (final s in p.photos)
        {
          'animal_id': p.id,
          'photo_key': s['request_key'],
          'path': photo(s).path,
          'sha256': s['sha256'],
        },
  ];
}

/// Derived small PNGs are excluded from backups; original JPEGs stay immutable.
class ProfileThumbnails {
  ProfileThumbnails(this.catalog, this.maxSide);
  final ProfileCatalog catalog;
  final int maxSide;
  final _jobs = <String, Future<File?>>{};
  Future<File?> get(Map? scan) {
    if (scan == null) return Future.value(null);
    return _jobs.putIfAbsent(scan['sha256'] as String, () => _make(scan));
  }

  Future<File?> _make(Map scan) async {
    try {
      final source = catalog.photo(scan);
      if (await FileSystemEntity.type(source.path, followLinks: false) !=
          FileSystemEntityType.file) {
        return null;
      }
      final dir = Directory('${catalog.store.root.path}/derived-thumbnails');
      await dir.create();
      final file = File('${dir.path}/${scan['sha256']}-$maxSide.png');
      if (await file.exists()) return file;
      final buffer = await ui.ImmutableBuffer.fromFilePath(source.path);
      ui.ImageDescriptor? descriptor;
      ui.Codec? codec;
      ui.Image? image;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        final scale = math.min(
          1.0,
          maxSide / math.max(descriptor.width, descriptor.height),
        );
        codec = await descriptor.instantiateCodec(
          targetWidth: math.max(1, (descriptor.width * scale).round()),
          targetHeight: math.max(1, (descriptor.height * scale).round()),
        );
        image = (await codec.getNextFrame()).image;
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) return null;
        final tmp = File('${file.path}.${randomFieldKey()}.next');
        await tmp.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
        return await tmp.rename(file.path);
      } finally {
        image?.dispose();
        codec?.dispose();
        descriptor?.dispose();
        buffer.dispose();
      }
    } catch (_) {
      return null;
    }
  }
}
