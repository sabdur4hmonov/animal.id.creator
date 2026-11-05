import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'ar_math.dart';

double finiteNumber(Object? v) {
  if (v is! num || !v.isFinite) {
    throw const FormatException('Nonfinite snapshot value');
  }
  return v.toDouble();
}

/// Frozen frame only. ARCore camera axes are +X right, +Y up, -Z forward.
Map<String, dynamic> unprojectSnapshot(Map frame, double x, double y, Map ar) {
  if (frame['measurement_source'] != 'arcore_frozen_raw_depth' ||
      frame['units'] != 'm' ||
      frame['frame_id'] is! String ||
      (frame['frame_id'] as String).isEmpty ||
      !RegExp(
        r'^[1-9][0-9]*$',
      ).hasMatch(frame['camera_timestamp_ns'].toString()) ||
      frame['tracking'] != 'TRACKING' ||
      frame['depth_timestamp_ns'] != frame['camera_timestamp_ns'] ||
      frame['confidence_timestamp_ns'] != frame['camera_timestamp_ns']) {
    throw const FormatException(
      'Depth and camera must belong to exactly one frame',
    );
  }
  final w = frame['depth_width'] as int, h = frame['depth_height'] as int;
  if (w <= 0 || h <= 0 || w * h > (ar['snapshot_max_depth_pixels'] as int)) {
    throw const FormatException('Invalid depth dimensions');
  }
  final vw = finiteNumber(frame['view_width']),
      vh = finiteNumber(frame['view_height']);
  if (!x.isFinite ||
      !y.isFinite ||
      vw <= 0 ||
      vh <= 0 ||
      x < 0 ||
      y < 0 ||
      x >= vw ||
      y >= vh) {
    throw const FormatException('Outside frozen image');
  }
  final mapping = (frame['view_to_image_normalized'] as List)
      .map(finiteNumber)
      .toList();
  if (mapping.length != 6) {
    throw const FormatException('Invalid frozen display transform');
  }
  final u =
      mapping[0] +
      x / vw * (mapping[2] - mapping[0]) +
      y / vh * (mapping[4] - mapping[0]);
  final v =
      mapping[1] +
      x / vw * (mapping[3] - mapping[1]) +
      y / vh * (mapping[5] - mapping[1]);
  if (u < 0 || v < 0 || u >= 1 || v >= 1) {
    throw const FormatException('Outside depth image');
  }
  final px = (u * w).floor(), py = (v * h).floor(), index = py * w + px;
  final depth = base64Decode(frame['depth_u16le_base64'] as String),
      confidence = base64Decode(frame['confidence_u8_base64'] as String);
  if (depth.length != w * h * 2 || confidence.length != w * h) {
    throw const FormatException('Truncated frozen depth');
  }
  final score = confidence[index] / 255.0,
      z =
          ByteData.sublistView(depth).getUint16(index * 2, Endian.little) /
          1000.0;
  if (score < (ar['snapshot_min_point_confidence'] as num) ||
      z < (ar['snapshot_min_depth_m'] as num) ||
      z > (ar['snapshot_max_depth_m'] as num)) {
    throw const FormatException('No confident depth at selected pixel');
  }
  final k = frame['depth_intrinsics'] as Map;
  final fx = finiteNumber(k['fx']),
      fy = finiteNumber(k['fy']),
      cx = finiteNumber(k['cx']),
      cy = finiteNumber(k['cy']);
  if (fx <= 0 || fy <= 0) throw const FormatException('Invalid intrinsics');
  final camera = [(px - cx) * z / fx, -(py - cy) * z / fy, -z];
  final pose = (frame['camera_pose_column_major'] as List)
      .map(finiteNumber)
      .toList();
  if (pose.length != 16 ||
      pose[3].abs() > 1e-5 ||
      pose[7].abs() > 1e-5 ||
      pose[11].abs() > 1e-5 ||
      (pose[15] - 1).abs() > 1e-5) {
    throw const FormatException('Invalid rigid camera pose');
  }
  for (var i = 0; i < 3; i++) {
    for (var j = 0; j < 3; j++) {
      final dot = List.generate(
        3,
        (axis) => pose[i * 4 + axis] * pose[j * 4 + axis],
      ).reduce((a, b) => a + b);
      if ((dot - (i == j ? 1 : 0)).abs() > 1e-4) {
        throw const FormatException('Camera pose is not rigid');
      }
    }
  }
  final world = List.generate(
    3,
    (r) =>
        pose[r] * camera[0] +
        pose[4 + r] * camera[1] +
        pose[8 + r] * camera[2] +
        pose[12 + r],
  );
  return {
    'x': world[0],
    'y': world[1],
    'z': world[2],
    'confidence': score,
    'tracking': 'TRACKING',
    'frame_id': frame['frame_id'],
    'frame_ns': frame['camera_timestamp_ns'],
    'screen_x': x,
    'screen_y': y,
    'depth_pixel_x': px,
    'depth_pixel_y': py,
    'depth_m': z,
    'image_normalized_x': u,
    'image_normalized_y': v,
    'unprojection_method': 'pinhole_depth_integer_pixel_center_arcore_axes_v1',
  };
}

double snapshotDistance(Map frame, int start, int end, Map ar) {
  final points = frame['points'] as List;
  final a = points[start] as Map, b = points[end] as Map;
  if ([a, b].any(
    (p) =>
        p['frame_id'] != frame['frame_id'] ||
        p['frame_ns'] != frame['camera_timestamp_ns'],
  )) {
    throw const FormatException('Cross-frame points rejected');
  }
  // Recompute from raw bytes: stored world coordinates/confidence are never trusted.
  final p = unprojectSnapshot(
    frame,
    finiteNumber(a['screen_x']),
    finiteNumber(a['screen_y']),
    ar,
  );
  final q = unprojectSnapshot(
    frame,
    finiteNumber(b['screen_x']),
    finiteNumber(b['screen_y']),
    ar,
  );
  if (p['depth_pixel_x'] == q['depth_pixel_x'] &&
      p['depth_pixel_y'] == q['depth_pixel_y']) {
    throw const FormatException('Repeated depth pixel');
  }
  final cm = ArPoint.json(p).distance(ArPoint.json(q)) * 100;
  if (cm < (ar['min_segment_cm'] as num) ||
      cm > (ar['max_segment_cm'] as num)) {
    throw const FormatException('Snapshot segment outside range');
  }
  return cm;
}

double ellipseGirth(double depth, double width) {
  final a = depth / 2,
      b = width / 2,
      h = math.pow(a - b, 2) / math.pow(a + b, 2);
  return math.pi * (a + b) * (1 + 3 * h / (10 + math.sqrt(4 - 3 * h)));
}

/// No distances are ever computed between frames, even if their maps share an origin.
Map<String, dynamic> measureSnapshotSet(
  List<Map<String, dynamic>> frames,
  Map config,
  String breed,
  Map? ratio,
) {
  final ar = config['ar'] as Map;
  if (config['enabled'] != true ||
      frames.length < 2 ||
      frames.length > 3 ||
      frames[0]['view'] != 'left' ||
      frames[1]['view'] != 'right' ||
      frames.length == 3 && frames[2]['view'] != 'front') {
    throw const FormatException(
      'Left/right and optional front frames required',
    );
  }
  if (frames.map((f) => f['frame_id']).toSet().length != frames.length ||
      frames.map((f) => f['camera_timestamp_ns']).toSet().length !=
          frames.length) {
    throw const FormatException('Independent frames required');
  }
  for (final f in frames) {
    if ((f['points'] as List).length != (f['view'] == 'front' ? 2 : 4)) {
      throw const FormatException('Wrong frozen point count');
    }
  }
  final lengths = [
    for (final f in frames.take(2)) snapshotDistance(f, 0, 1, ar),
  ];
  final depths = [
    for (final f in frames.take(2)) snapshotDistance(f, 2, 3, ar),
  ];
  final length = (lengths[0] + lengths[1]) / 2,
      depth = (depths[0] + depths[1]) / 2;
  double width;
  String widthSource, calibrationMode;
  if (frames.length == 3) {
    width = snapshotDistance(frames[2], 0, 1, ar);
    widthSource = 'front_snapshot';
    calibrationMode = 'snapshot:front_snapshot';
  } else {
    if (ratio == null ||
        ratio['species'] != config['species'] ||
        ratio['breed'] != breed ||
        ratio['sample_count'] < (ar['snapshot_min_ratio_animals'] as int) ||
        ratio['ratio'] == null) {
      throw const FormatException(
        'Insufficient measured animals for width ratio',
      );
    }
    final value = finiteNumber(ratio['ratio']);
    if (value <= 0) throw const FormatException('Invalid learned ratio');
    width = depth * value;
    widthSource = 'learned_ratio:${ratio['revision']}';
    calibrationMode = 'snapshot:learned_ratio:${ratio['key']}';
  }
  if (width < (ar['min_segment_cm'] as num) ||
      width > (ar['max_segment_cm'] as num)) {
    throw const FormatException('Estimated width outside range');
  }
  final girth = ellipseGirth(depth, width),
      weights = formulaWeights(girth, length, breed, config['weight']);
  final differences = {
    'body_length_cm': repeatDifference(lengths),
    'chest_depth_cm': repeatDifference(depths),
  };
  final sideGirth = [
    for (final d in depths)
      ellipseGirth(
        d,
        frames.length == 3 ? width : d * finiteNumber(ratio!['ratio']),
      ),
  ];
  differences['chest_girth_cm'] = repeatDifference(sideGirth);
  for (final f in weights.keys) {
    differences[f] = repeatDifference(
      List.generate(
        2,
        (i) => formulaWeights(
          sideGirth[i],
          lengths[i],
          breed,
          config['weight'],
        )[f]!.number,
      ),
    );
  }
  final difference = differences.values.reduce(math.max);
  return {
    'mode': 'snapshot',
    'calibration_mode': calibrationMode,
    'width_source': widthSource,
    'ratio_revision': frames.length == 3 ? null : ratio!['revision'],
    'ratio_sample_count': frames.length == 3 ? null : ratio!['sample_count'],
    'ratio_snapshot': frames.length == 3 ? null : ratio,
    'body_length_cm': length,
    'chest_depth_cm': depth,
    'chest_width_cm': width,
    'chest_girth_cm': girth,
    'girth_method': 'ramanujan_ellipse_ii',
    'side_lengths_cm': lengths,
    'side_depths_cm': depths,
    'differences_pct': differences,
    'repeat_difference_pct': difference,
    'valid': difference <= (ar['max_repeat_difference_pct'] as num),
    'weights_kg': weights.map(
      (k, v) => MapEntry(k, v.number.toStringAsFixed(6)),
    ),
    'girth_calibrated': false,
    'real_world_accuracy_verified': false,
  };
}
