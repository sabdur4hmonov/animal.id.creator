import 'dart:math' as math;

/// Fixed-point decimal arithmetic for formulas/money. Geometry alone uses doubles.
class Amount {
  Amount(this.units);
  final BigInt units;
  static final scale = BigInt.from(1000000);
  factory Amount.parse(Object value) {
    final s = value.toString();
    if (!RegExp(r'^\d+(?:\.\d{1,6})?$').hasMatch(s)) {
      throw const FormatException('Invalid nonnegative decimal');
    }
    final parts = s.split('.');
    return Amount(
      BigInt.parse(parts[0]) * scale +
          BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(6, '0')),
    );
  }
  factory Amount.geometry(double value) {
    if (!value.isFinite || value <= 0) {
      throw const FormatException('Invalid geometry');
    }
    return Amount.parse(value.toStringAsFixed(6));
  }
  Amount operator +(Amount other) => Amount(units + other.units);
  Amount operator *(Amount other) =>
      Amount((units * other.units + scale ~/ BigInt.two) ~/ scale);
  Amount operator /(Amount other) {
    if (other.units <= BigInt.zero) {
      throw const FormatException('Zero denominator');
    }
    return Amount((units * scale + other.units ~/ BigInt.two) ~/ other.units);
  }

  double get number => units.toDouble() / scale.toDouble();
  String get text => number.toStringAsFixed(2);
  String atPrice(String integerSom) {
    if (!RegExp(r'^\d{1,12}$').hasMatch(integerSom) ||
        BigInt.parse(integerSom) <= BigInt.zero) {
      throw const FormatException('Use positive integer UZS');
    }
    return ((units * BigInt.parse(integerSom) + scale ~/ BigInt.two) ~/ scale)
        .toString();
  }
}

class ArPoint {
  ArPoint(
    this.x,
    this.y,
    this.z, {
    this.confidence = 1,
    this.tracking = 'TRACKING',
  });
  final double x, y, z, confidence;
  final String tracking;
  factory ArPoint.json(Map value) => ArPoint(
    (value['x'] as num).toDouble(),
    (value['y'] as num).toDouble(),
    (value['z'] as num).toDouble(),
    confidence: (value['confidence'] as num).toDouble(),
    tracking: value['tracking'] as String,
  );
  List<double> get vector => [x, y, z];
  double distance(ArPoint other) => math.sqrt(
    math.pow(x - other.x, 2) +
        math.pow(y - other.y, 2) +
        math.pow(z - other.z, 2),
  );
}

double _dot(List<double> a, List<double> b) =>
    List.generate(3, (i) => a[i] * b[i]).reduce((a, b) => a + b);
List<double> _sub(List<double> a, List<double> b) =>
    List.generate(3, (i) => a[i] - b[i]);
double _orientation(List<double> a, List<double> b, List<double> c) =>
    (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
bool _on(List<double> a, List<double> b, List<double> p, double e) =>
    [0, 1].every(
      (i) =>
          p[i] >= math.min(a[i], b[i]) - e && p[i] <= math.max(a[i], b[i]) + e,
    );
bool _intersects(
  List<double> a,
  List<double> b,
  List<double> c,
  List<double> d,
  double e,
) {
  final o = [
    _orientation(a, b, c),
    _orientation(a, b, d),
    _orientation(c, d, a),
    _orientation(c, d, b),
  ];
  bool opposite(double x, double y) => x > e && y < -e || x < -e && y > e;
  if (opposite(o[0], o[1]) && opposite(o[2], o[3])) return true;
  return o[0].abs() <= e && _on(a, b, c, e) ||
      o[1].abs() <= e && _on(a, b, d, e) ||
      o[2].abs() <= e && _on(c, d, a, e) ||
      o[3].abs() <= e && _on(c, d, b, e);
}

/// Jacobi eigendecomposition of centered covariance equals the Python SVD right axes.
List<List<double>> contourAxes(List<List<double>> points) {
  final a = List.generate(
    3,
    (i) => List.generate(
      3,
      (j) => points.fold(0.0, (sum, p) => sum + p[i] * p[j]),
    ),
  );
  final v = List.generate(
    3,
    (i) => List.generate(3, (j) => i == j ? 1.0 : 0.0),
  );
  for (var iteration = 0; iteration < 80; iteration++) {
    var p = 0, q = 1;
    for (var i = 0; i < 3; i++) {
      for (var j = i + 1; j < 3; j++) {
        if (a[i][j].abs() > a[p][q].abs()) {
          p = i;
          q = j;
        }
      }
    }
    if (a[p][q].abs() < 1e-15) break;
    final angle = .5 * math.atan2(2 * a[p][q], a[q][q] - a[p][p]);
    final c = math.cos(angle), s = math.sin(angle);
    final app = a[p][p], aqq = a[q][q], apq = a[p][q];
    a[p][p] = c * c * app - 2 * s * c * apq + s * s * aqq;
    a[q][q] = s * s * app + 2 * s * c * apq + c * c * aqq;
    a[p][q] = 0;
    a[q][p] = 0;
    for (var k = 0; k < 3; k++) {
      if (k != p && k != q) {
        final akp = a[k][p], akq = a[k][q];
        a[k][p] = c * akp - s * akq;
        a[p][k] = a[k][p];
        a[k][q] = s * akp + c * akq;
        a[q][k] = a[k][q];
      }
      final vkp = v[k][p], vkq = v[k][q];
      v[k][p] = c * vkp - s * vkq;
      v[k][q] = s * vkp + c * vkq;
    }
  }
  final order = [0, 1, 2]..sort((i, j) => a[j][j].compareTo(a[i][i]));
  return [
    for (final i in order) [a[i][i], for (var k = 0; k < 3; k++) v[k][i]],
  ];
}

void validateContour(List<ArPoint> contour, Map config) {
  if (contour.length < 3 ||
      contour.map((p) => p.vector.join(',')).toSet().length != contour.length) {
    throw const FormatException('Repeated or missing contour points');
  }
  final mean = List.generate(
    3,
    (i) => contour.fold(0.0, (s, p) => s + p.vector[i]) / contour.length,
  );
  final centered = contour.map((p) => _sub(p.vector, mean)).toList();
  final span = centered.map((p) => math.sqrt(_dot(p, p))).reduce(math.max);
  if (span <= 0) throw const FormatException('Contour has no extent');
  final normalized = centered
      .map((p) => p.map((v) => v / span).toList())
      .toList();
  final axes = contourAxes(normalized);
  final e = (config['contour_geometric_epsilon_ratio'] as num).toDouble();
  if (axes[1][0] <= e * e * axes[0][0]) {
    throw const FormatException('Contour is a line');
  }
  if (normalized.any(
    (p) =>
        _dot(p, axes[2].sublist(1)).abs() >
        (config['contour_max_planarity_error_ratio'] as num),
  )) {
    throw const FormatException('Contour is not planar');
  }
  final projected = normalized
      .map((p) => [_dot(p, axes[0].sublist(1)), _dot(p, axes[1].sublist(1))])
      .toList();
  final count = contour.length;
  for (var i = 0; i < count; i++) {
    final current = projected[i],
        following = projected[(i + 1) % count],
        previous = projected[(i - 1 + count) % count];
    if (math.sqrt(
          math.pow(current[0] - following[0], 2) +
              math.pow(current[1] - following[1], 2),
        ) <=
        e) {
      throw const FormatException('Indistinguishable projected points');
    }
    if (_orientation(previous, current, following).abs() <= e &&
        (previous[0] - current[0]) * (following[0] - current[0]) +
                (previous[1] - current[1]) * (following[1] - current[1]) >
            e) {
      throw const FormatException('Contour retraces edge');
    }
    for (var j = i + 1; j < count; j++) {
      if (j == i + 1 || i == 0 && j == count - 1) continue;
      if (_intersects(
        current,
        following,
        projected[j],
        projected[(j + 1) % count],
        e,
      )) {
        throw const FormatException('Contour intersects');
      }
    }
  }
}

Map<String, Amount> formulaWeights(
  double girthCm,
  double lengthCm,
  String breed,
  Map weight,
) {
  if (!girthCm.isFinite ||
      !lengthCm.isFinite ||
      girthCm <= 0 ||
      lengthCm <= 0 ||
      girthCm > 500 ||
      lengthCm > 500) {
    throw const FormatException('Measurements outside range');
  }
  final factor = (weight['trukhanovsky_factors'] as Map)[breed];
  if (factor == null) throw const FormatException('Unknown breed category');
  final girth = Amount.geometry(girthCm),
      length = Amount.geometry(lengthCm),
      denominator = Amount.parse(weight['denominator']);
  final adjusted = girth + Amount.parse(weight['schoorl_offset_cm']);
  return {
    'trukhanovsky': girth * length * Amount.parse(factor) / denominator,
    'schoorl': adjusted * adjusted / denominator,
  };
}

Map<String, dynamic> measureAr(Map raw, Map config, String breed) {
  if (config['enabled'] != true ||
      raw['measurement_source'] != 'arcore_metric' ||
      raw['units'] != 'm') {
    throw const FormatException('Missing metric AR provenance');
  }
  final ar = config['ar'] as Map, weight = config['weight'] as Map;
  final mode = raw['mode'];
  final duration = raw['duration_seconds'];
  if (duration is! num ||
      !duration.isFinite ||
      duration <= 0 ||
      duration > (ar['max_session_seconds'] as num) ||
      raw['tracking_history'] is! List ||
      (raw['tracking_history'] as List).isEmpty ||
      ((raw['tracking_history'] as List).last as Map)['state'] != 'TRACKING') {
    throw const FormatException('Invalid AR duration/tracking history');
  }
  if (!{'fast', 'contour'}.contains(mode)) {
    throw const FormatException('Unknown measurement mode');
  }
  final points = (raw['points'] as List)
      .map((p) => ArPoint.json(p as Map))
      .toList();
  if (points.any(
    (p) =>
        ![p.x, p.y, p.z, p.confidence].every((v) => v.isFinite) ||
        p.confidence < (ar['min_point_confidence'] as num) ||
        p.confidence > 1 ||
        p.tracking != 'TRACKING',
  )) {
    throw const FormatException('Unreliable AR point');
  }
  if (mode == 'fast' && points.length != 6 ||
      mode == 'contour' &&
          (points.length < 2 + (ar['min_contour_points'] as int) ||
              points.length > 2 + (ar['max_contour_points'] as int))) {
    throw const FormatException('Wrong point count');
  }
  double segment(int a, int b) {
    final value = points[a].distance(points[b]) * 100;
    if (value < (ar['min_segment_cm'] as num) ||
        value > (ar['max_segment_cm'] as num)) {
      throw const FormatException('Segment outside range');
    }
    return value;
  }

  final length = segment(0, 1);
  double girth;
  final segments = <String, dynamic>{'body_length_cm': length};
  if (mode == 'fast') {
    final depth = segment(2, 3), width = segment(4, 5);
    final a = depth / 2,
        b = width / 2,
        h = math.pow(a - b, 2) / math.pow(a + b, 2);
    girth = math.pi * (a + b) * (1 + 3 * h / (10 + math.sqrt(4 - 3 * h)));
    segments.addAll({'chest_depth_cm': depth, 'chest_width_cm': width});
  } else {
    final contour = points.sublist(2);
    validateContour(contour, weight);
    final edges = List.generate(
      contour.length,
      (i) => contour[i].distance(contour[(i + 1) % contour.length]) * 100,
    );
    girth = edges.reduce((a, b) => a + b);
    segments['contour_edges_cm'] = edges;
  }
  final scale = raw['scale_check'];
  if (scale is Map) {
    final expected = (scale['expected_cm'] as num).toDouble(),
        actual = (scale['measured_cm'] as num).toDouble();
    if (!expected.isFinite ||
        !actual.isFinite ||
        expected <= 0 ||
        actual <= 0 ||
        (actual - expected).abs() / expected * 100 >
            (ar['max_scale_check_error_pct'] as num)) {
      throw const FormatException('Scale check failed');
    }
  }
  final values = formulaWeights(girth, length, breed, weight);
  return {
    'mode': mode,
    'girth_method': mode == 'fast'
        ? 'ramanujan_ellipse_ii'
        : 'ordered_closed_contour',
    'chest_girth_cm': girth,
    ...segments,
    'breed': breed,
    'weights_kg': values.map(
      (key, value) => MapEntry(key, value.number.toStringAsFixed(6)),
    ),
    'real_world_accuracy_verified': false,
    'girth_calibrated': false,
  };
}

double repeatDifference(List<double> values) {
  if (values.length < 2 || values.any((v) => !v.isFinite || v <= 0)) {
    throw const FormatException('At least two valid repeats required');
  }
  return (values.reduce(math.max) - values.reduce(math.min)) /
      (values.reduce((a, b) => a + b) / values.length) *
      100;
}
