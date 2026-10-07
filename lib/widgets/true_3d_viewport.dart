import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_helpers/three_js_helpers.dart' as helpers;

import 'math_3d_visuals.dart' show Math3DConfig, PyramidBaseKind;

/// Base-vertex letters for an n-sided pyramid/prism base, in order
/// (A, B, C, ...). "S" is skipped/reserved for the apex.
const List<String> _polygonLetters = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

/// A real WebGL viewport for educational geometry.
///
/// Unlike the previous CustomPainter implementation, this widget owns a
/// perspective camera, orbit controls, depth testing, physically based
/// materials, lights and a real grid. It is intentionally kept separate from
/// the text parser so it can also render lesson/exam visuals.
class _WorldLabel {
  final String text;
  final three.Vector3 position;
  final int color;
  final bool axis;
  final double dx;
  final double dy;

  const _WorldLabel(
    this.text,
    this.position,
    this.color,
    this.axis, {
    this.dx = 0,
    this.dy = 0,
  });
}

class _ViewportLabel {
  final String text;
  final double x;
  final double y;
  final int color;
  final bool axis;

  const _ViewportLabel(this.text, this.x, this.y, this.color, this.axis);
}

class _DistanceVisual {
  final three.Vector3 start;
  final three.Vector3 end;
  final String label;

  const _DistanceVisual(this.start, this.end, this.label);
}

/// What one side of a "khoảng cách từ X đến Y" request resolved to.
enum _TokenKind { point, line, plane }

class _GeometryToken {
  final _TokenKind kind;
  final List<three.Vector3> points;
  final String label;

  const _GeometryToken(this.kind, this.points, this.label);
}

class True3DViewport extends StatefulWidget {
  final dynamic config;
  final double height;

  const True3DViewport({
    super.key,
    required this.config,
    this.height = 320,
  });

  @override
  State<True3DViewport> createState() => _True3DViewportState();
}

class _True3DViewportState extends State<True3DViewport> {
  late final three.ThreeJS _threeJs;
  three.OrbitControls? _controls;
  three.Object3D? _modelRoot;
  final ValueNotifier<List<_ViewportLabel>> _labels = ValueNotifier(const []);
  double _viewportWidth = 0;
  double _viewportHeight = 0;

  @override
  void initState() {
    super.initState();
    _threeJs = three.ThreeJS(
      settings: three.Settings(
        antialias: true,
        enableShadowMap: true,
        clearColor: 0xf7f6ff,
        clearAlpha: 1,
        powerPreference: three.PowerPreference.high,
      ),
      onSetupComplete: () {
        if (mounted) setState(() {});
      },
      setup: _setup,
    );
  }

  @override
  void didUpdateWidget(covariant True3DViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config && _threeJs.mounted) {
      _rebuildModel();
    }
  }

  @override
  void dispose() {
    _controls?.clearListeners();
    _labels.dispose();
    _threeJs.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    _threeJs.camera = three.PerspectiveCamera(
      42,
      _threeJs.width / math.max(1, _threeJs.height),
      0.05,
      1000,
    );
    _threeJs.camera.up.setValues(0, 0, 1);
    if (_isRectangularPyramid(widget.config)) {
      _threeJs.camera.position.setValues(-7.0, -9.0, 5.6);
    } else {
      _threeJs.camera.position.setValues(4.2, -4.8, 3.4);
    }

    _threeJs.scene = three.Scene();
    _addLighting();
    _addWorkspace();
    _rebuildModel();

    _controls = three.OrbitControls(_threeJs.camera, _threeJs.globalKey)
      ..enableDamping = true
      ..dampingFactor = 0.08
      ..enablePan = true
      ..enableRotate = true
      ..enableZoom = true
      ..rotateSpeed = 0.65
      ..zoomSpeed = 0.8
      ..panSpeed = 0.8
      ..minDistance = 2.2
      ..maxDistance = 38
      ..minPolarAngle = 0.12
      ..maxPolarAngle = math.pi - 0.12
      ..screenSpacePanning = true;
    _controls!.target.setValues(0, 0, _targetHeight());
    _threeJs.camera.lookAt(_controls!.target);
    _controls!.update();

    _threeJs.addAnimationEvent((_) {
      _controls?.update();
      _updateLabels();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateLabels());
  }

  void _addLighting() {
    final ambient = three.AmbientLight(0xffffff, 1.25);
    _threeJs.scene.add(ambient);

    final key = three.DirectionalLight(0xffffff, 2.8);
    key.position.setValues(5, -6, 10);
    key.castShadow = true;
    key.shadow!.mapSize.setValues(2048, 2048);
    _threeJs.scene.add(key);

    final fill = three.DirectionalLight(0x9a8cff, 1.2);
    fill.position.setValues(-7, 4, 5);
    _threeJs.scene.add(fill);
  }

  void _addWorkspace() {
    final grid = helpers.GridHelper(14, 28, 0x786ee8, 0xdedcff);
    grid.rotation.x = math.pi / 2;
    grid.position.z = -0.012;
    _threeJs.scene.add(grid);

    final origin = three.Vector3(0, 0, 0.01);
    _threeJs.scene.add(helpers.ArrowHelper(
      three.Vector3(1, 0, 0),
      origin,
      5.5,
      0xd84b5b,
      0.28,
      0.14,
    ));
    _threeJs.scene.add(helpers.ArrowHelper(
      three.Vector3(0, 1, 0),
      origin,
      5.5,
      0x2caa68,
      0.28,
      0.14,
    ));
    _threeJs.scene.add(helpers.ArrowHelper(
      three.Vector3(0, 0, 1),
      origin,
      5.5,
      0x3c78d8,
      0.28,
      0.14,
    ));
  }

  void _rebuildModel() {
    if (_modelRoot != null) {
      _threeJs.scene.remove(_modelRoot!);
      _modelRoot!.dispose();
    }

    final root = three.Group();
    _modelRoot = root;
    _threeJs.scene.add(root);

    final geometry = _makeGeometry(widget.config);
    final material = three.MeshStandardMaterial({
      three.MaterialProperty.color: _materialColor(widget.config.shape),
      three.MaterialProperty.roughness: 0.38,
      three.MaterialProperty.metalness: 0.04,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.opacity: 0.34,
      three.MaterialProperty.depthWrite: false,
      three.MaterialProperty.side: three.DoubleSide,
    });
    final mesh = three.Mesh(geometry, material);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    mesh.rotation.x = math.pi / 2;
    mesh.position.z = _isGroundedGeometry() ? 0 : _objectHeight() / 2;
    root.add(mesh);

    final edgeGeometry = three.EdgesGeometry(geometry, 20);
    final edgeMaterial = three.LineBasicMaterial({
      three.MaterialProperty.color: 0x4d43af,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.opacity: 0.9,
      three.MaterialProperty.depthTest: false,
    });
    final outline = three.LineSegments(edgeGeometry, edgeMaterial);
    outline.rotation.x = math.pi / 2;
    outline.position.z = _isGroundedGeometry() ? 0 : _objectHeight() / 2;
    root.add(outline);
    if (_isRectangularPyramid(widget.config)) {
      _addRectangularBaseFrame(root);
    }

    final baseVertices = _rawNamedVertices();
    final auxiliaryPoints = baseVertices.isNotEmpty
        ? _definedAuxiliaryPoints(baseVertices)
        : const <String, three.Vector3>{};
    if (auxiliaryPoints.isNotEmpty) {
      _addAuxiliaryPointMarkers(root, auxiliaryPoints.values);
    }

    final distance = _distanceVisual();
    if (distance != null) _addDistanceVisual(root, distance);

    if (_controls != null) {
      _controls!.target.setValues(0, 0, _targetHeight());
      _controls!.update();
    }
    _updateLabels();
  }

  void _addRectangularBaseFrame(three.Object3D root) {
    final width = (widget.config.width as num).toDouble();
    final depth = (widget.config.depth as num).toDouble();
    final x = width / 2;
    final y = depth / 2;
    final points = <double>[
      -x,
      0,
      y,
      x,
      0,
      y,
      x,
      0,
      y,
      x,
      0,
      -y,
      x,
      0,
      -y,
      -x,
      0,
      -y,
      -x,
      0,
      -y,
      -x,
      0,
      y,
    ];
    final geometry = three.BufferGeometry();
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(points, 3, false),
    );
    final material = three.LineBasicMaterial({
      three.MaterialProperty.color: 0x3f35a5,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.opacity: 1.0,
      three.MaterialProperty.depthTest: false,
    });
    final frame = three.LineSegments(geometry, material);
    frame.rotation.x = math.pi / 2;
    frame.position.z = 0.006;
    root.add(frame);
    _addRectangularBaseSurface(root, x, y);

    final vertexMaterial = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x4d43af,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.opacity: 1.0,
      three.MaterialProperty.depthTest: false,
    });
    final vertices = [
      three.Vector3(-x, -y, 0),
      three.Vector3(x, -y, 0),
      three.Vector3(x, y, 0),
      three.Vector3(-x, y, 0),
      three.Vector3(-x, -y, (widget.config.height as num).toDouble()),
    ];
    for (final position in vertices) {
      final marker =
          three.Mesh(three.SphereGeometry(0.085, 12, 8), vertexMaterial);
      marker.position.setFrom(position);
      root.add(marker);
    }
  }

  void _addRectangularBaseSurface(three.Object3D root, double x, double y) {
    final geometry = three.BufferGeometry();
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(<double>[
        -x,
        0,
        y,
        x,
        0,
        y,
        x,
        0,
        -y,
        -x,
        0,
        -y,
      ], 3, false),
    );
    geometry.setIndex(<int>[0, 1, 2, 0, 2, 3]);
    geometry.computeVertexNormals();
    final material = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0x6f64d8,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.opacity: 0.16,
      three.MaterialProperty.depthWrite: false,
      three.MaterialProperty.depthTest: false,
      three.MaterialProperty.side: three.DoubleSide,
    });
    final surface = three.Mesh(geometry, material);
    surface.rotation.x = math.pi / 2;
    surface.position.z = 0.003;
    root.add(surface);
  }

  /// Small solid markers for points the prompt DEFINES rather than names
  /// as part of the solid itself (currently midpoints, e.g. "gọi H là
  /// trung điểm AC") — these sit inside/along the solid rather than at one
  /// of its outer corners, so unlike A, B, C... they need an explicit dot
  /// to actually be visible; a floating text label alone wouldn't show
  /// where the point really is.
  void _addAuxiliaryPointMarkers(
      three.Object3D root, Iterable<three.Vector3> points) {
    final material = three.MeshBasicMaterial({
      three.MaterialProperty.color: 0xe0793c,
      three.MaterialProperty.transparent: true,
      three.MaterialProperty.opacity: 1.0,
      three.MaterialProperty.depthTest: false,
    });
    for (final position in points) {
      final marker = three.Mesh(three.SphereGeometry(0.075, 12, 8), material);
      marker.position.setFrom(position);
      root.add(marker);
    }
  }

  /// Every named vertex the current solid exposes, in world space — the
  /// single lookup table the distance parser below uses, regardless of
  /// shape. Returns an empty map for shapes with no meaningful named
  /// vertices (cylinder/cone/sphere), which the caller falls back for.
  /// The actual base-vertex letters to use for a pyramid/tetrahedron with
  /// `n` base vertices: the ones the prompt explicitly named (e.g.
  /// ["A","P","M","E"] for "F.APME"), or the conventional A, B, C, D... .
  List<String> _effectiveBaseLabels(int n) {
    final custom = (widget.config.baseLabels as List).cast<String>();
    if (custom.length == n) return custom;
    return _polygonLetters.sublist(0, n.clamp(0, _polygonLetters.length));
  }

  String get _effectiveApexLabel => widget.config.apexLabel as String;

  Map<String, three.Vector3> _allNamedVertices() {
    final map = _rawNamedVertices();
    // Add the base's centroid as point "O" — a very common reference in
    // "chóp đều" problems ("khoảng cách từ tâm O của đáy đến (SCD)") — as
    // long as no ACTUAL named vertex is already called "O" (e.g. the "O"
    // in "E.PDOW"), which always takes priority. Excludes the apex label
    // (for pyramids) so this is the base's centroid, not the whole
    // solid's; for shapes with no apex concept (cuboid/prism) it's the
    // centroid of every listed vertex.
    if (map.isNotEmpty && !map.containsKey('O')) {
      final apex = _effectiveApexLabel;
      final basePoints =
          map.entries.where((e) => e.key != apex).map((e) => e.value);
      if (basePoints.isNotEmpty) {
        var sum = three.Vector3(0, 0, 0);
        var count = 0;
        for (final p in basePoints) {
          sum = sum.clone().add(p);
          count++;
        }
        map['O'] = sum.clone().scale(1 / count);
      }
    }
    if (map.isNotEmpty) {
      for (final entry in _definedAuxiliaryPoints(map).entries) {
        map.putIfAbsent(entry.key, () => entry.value);
      }
    }
    return map;
  }

  /// Points the prompt EXPLICITLY defines relative to the solid's named
  /// vertices — currently "gọi H là trung điểm AC" and similar midpoint
  /// definitions, the overwhelmingly common case in these problems. Found
  /// anywhere in the prompt (not just inside a "khoảng cách..." clause),
  /// so a defined point is drawn even if the question never ends up
  /// asking a distance about it — per the requirement that any point the
  /// problem introduces should appear in the model.
  Map<String, three.Vector3> _definedAuxiliaryPoints(
      Map<String, three.Vector3> vertices) {
    final folded = Math3DConfig.foldVietnamese(widget.config.title as String);
    final knownKeys = vertices.keys.toSet();
    final result = <String, three.Vector3>{};
    final pattern = RegExp(
      r'goi\s+([a-z])\s+la\s+trung\s*diem(?:\s*cua)?\s+([a-z]{2,4})',
    );
    for (final match in pattern.allMatches(folded)) {
      final pointName = match.group(1)!.toUpperCase();
      if (vertices.containsKey(pointName)) {
        continue; // A real named vertex always wins over a derived point.
      }
      final edgeLetters = _splitVertexNames(match.group(2)!, knownKeys);
      if (edgeLetters == null || edgeLetters.length != 2) continue;
      final p1 = vertices[edgeLetters[0]]!;
      final p2 = vertices[edgeLetters[1]]!;
      result[pointName] = p1.clone().lerp(p2, 0.5);
    }
    return result;
  }

  Map<String, three.Vector3> _rawNamedVertices() {
    final shape = _shapeName(widget.config.shape);
    final width = (widget.config.width as num).toDouble();
    final depth = (widget.config.depth as num).toDouble();
    final height = (widget.config.height as num).toDouble();
    switch (shape) {
      case 'cube':
        return _cuboidPoints(width, width, width);
      case 'cuboid':
        return _cuboidPoints(width, depth, height);
      case 'frustum':
        final topWidth = (widget.config.topWidth as num).toDouble();
        final topDepth = (widget.config.topDepth as num).toDouble();
        return _frustumPoints(width, depth, topWidth, topDepth, height);
      case 'pyramid':
      case 'tetrahedron':
        if (_isRectangularPyramid(widget.config)) {
          final labels = _effectiveBaseLabels(4);
          final base = _cuboidPoints(width, depth, height);
          const standard = ['A', 'B', 'C', 'D'];
          final map = <String, three.Vector3>{
            for (var i = 0; i < 4; i++) labels[i]: base[standard[i]]!,
          };
          final apexBaseIndex =
              (widget.config.apexBaseIndex as num).round().clamp(0, 3);
          final apexAbove = map[labels[apexBaseIndex]]!;
          map[_effectiveApexLabel] =
              three.Vector3(apexAbove.x, apexAbove.y, height);
          return map;
        }
        if (_isRightTrapezoidPyramid(widget.config)) {
          final labels = _effectiveBaseLabels(4);
          final x = width / 2, z = depth / 2;
          final topWidth = (widget.config.topWidth as num).toDouble();
          final base = {
            labels[0]: three.Vector3(-x, -z, 0), // A
            labels[1]: three.Vector3(x, -z, 0), // B
            labels[2]: three.Vector3(-x + topWidth, z, 0), // C
            labels[3]: three.Vector3(-x, z, 0), // D
          };
          final apexBaseIndex =
              (widget.config.apexBaseIndex as num).round().clamp(0, 3);
          final apexAbove = base[labels[apexBaseIndex]]!;
          return {
            ...base,
            _effectiveApexLabel:
                three.Vector3(apexAbove.x, apexAbove.y, height),
          };
        }
        if (_isTriangularPyramid(widget.config)) {
          final labels = _effectiveBaseLabels(3);
          final base = {
            labels[0]: three.Vector3(-width / 2, -depth / 2, 0),
            labels[1]: three.Vector3(width / 2, -depth / 2, 0),
            labels[2]: three.Vector3(width / 2, depth / 2, 0),
          };
          final apexBaseIndex =
              (widget.config.apexBaseIndex as num).round().clamp(0, 2);
          final apexAbove = base[labels[apexBaseIndex]]!;
          return {
            ...base,
            _effectiveApexLabel:
                three.Vector3(apexAbove.x, apexAbove.y, height),
          };
        }
        final n = (widget.config.sides as num).round().clamp(3, 24).toInt();
        final apexBaseIndex = (widget.config.apexBaseIndex as num).round();
        return _regularPyramidVertices(n, width, depth, height, apexBaseIndex,
            baseLabels: _effectiveBaseLabels(n),
            apexLabel: _effectiveApexLabel);
      case 'prism':
        if (widget.config.prismRightTriangleBase as bool) {
          return _rightTrianglePrismVertices(width, depth, height,
              (widget.config.prismRightAngleIndex as num).round());
        }
        final n = (widget.config.sides as num).round().clamp(3, 24).toInt();
        return _prismVertices(n, width, height);
      default:
        return {};
    }
  }

  Map<String, three.Vector3> _frustumPoints(double width, double depth,
      double topWidth, double topDepth, double height) {
    final x = width / 2;
    final y = depth / 2;
    final tx = topWidth / 2;
    final ty = topDepth / 2;
    return {
      'A': three.Vector3(-x, -y, 0),
      'B': three.Vector3(x, -y, 0),
      'C': three.Vector3(x, y, 0),
      'D': three.Vector3(-x, y, 0),
      "A'": three.Vector3(-tx, -ty, height),
      "B'": three.Vector3(tx, -ty, height),
      "C'": three.Vector3(tx, ty, height),
      "D'": three.Vector3(-tx, ty, height),
    };
  }

  /// Greedily splits an unbroken run of vertex-name characters (e.g. "sbc",
  /// "abcd", "a'b'c'") into the known vertex keys of the current solid, so
  /// "(sbc)" resolves to [S, B, C] and "a'b'c'd'" resolves to
  /// [A', B', C', D']. Returns null if any part of the run isn't a known
  /// vertex — a deliberately conservative failure mode: better to draw no
  /// purple line than a wrong one.
  List<String>? _splitVertexNames(String letters, Set<String> knownKeys) {
    final upper = letters.toUpperCase();
    final result = <String>[];
    var i = 0;
    while (i < upper.length) {
      String? found;
      if (i + 1 < upper.length && upper[i + 1] == "'") {
        final candidate = upper.substring(i, i + 2);
        if (knownKeys.contains(candidate)) found = candidate;
      }
      found ??= knownKeys.contains(upper[i]) ? upper[i] : null;
      if (found == null) return null;
      result.add(found);
      i += found.length;
    }
    return result.isEmpty ? null : result;
  }

  /// Resolves one side of "khoảng cách từ X đến Y" into a point, a line
  /// (2 vertices), or a plane (>=3 vertices) — for ANY combination of named
  /// vertices the current solid has, not a fixed list of textbook phrases.
  _GeometryToken? _resolveGeometryToken(
      String raw, Map<String, three.Vector3> vertices) {
    var text = raw.trim();
    final knownKeys = vertices.keys.toSet();

    final midpoint =
        RegExp(r'trung diem(?:\s*cua)?\s*([a-z\x27]+)').firstMatch(text);
    if (midpoint != null) {
      final letters = _splitVertexNames(midpoint.group(1)!, knownKeys);
      if (letters != null && letters.length == 2) {
        final p1 = vertices[letters[0]]!;
        final p2 = vertices[letters[1]]!;
        final mid = p1.clone().lerp(p2, 0.5);
        return _GeometryToken(
            _TokenKind.point, [mid], 'trung điểm ${letters[0]}${letters[1]}');
      }
    }

    final isPlaneHint = text.contains('mat phang') || text.contains('mp');
    text = text
        .replaceAll('mat phang', ' ')
        .replaceAll('duong thang', ' ')
        .replaceAll('diem', ' ')
        .replaceAll(
            'tam ', ' ') // "tâm O", "tâm B" — "center", not a plane hint
        .replaceAll('cua day', ' ') // "tâm O CỦA ĐÁY ABCD" — strip the filler
        .replaceAll('hai ', ' ')
        .replaceAll('mp', ' ');

    // Scan word by word instead of smashing the whole remainder into one
    // string: the outer sentence regex can't always cut cleanly at the end
    // ("... đến mặt phẳng SBC bằng", "... đến AC hay không"), so trailing
    // filler words ("bằng", "hay", "không"...) would otherwise glue onto
    // the real vertex letters ("sbc" + "bang" -> "sbcbang") and fail to
    // parse. Taking the first word that parses as a run of known vertex
    // names sidesteps that without needing a filler-word blocklist.
    List<String>? letters;
    for (final word in text.split(RegExp(r'\s+'))) {
      final cleaned = word.replaceAll(RegExp(r"[^a-z']"), '');
      if (cleaned.isEmpty) continue;
      final parsed = _splitVertexNames(cleaned, knownKeys);
      if (parsed != null) {
        letters = parsed;
        break;
      }
    }
    if (letters == null || letters.isEmpty) return null;
    final points = letters.map((l) => vertices[l]!).toList();
    final label = letters.join();
    if (letters.length == 1) {
      return _GeometryToken(_TokenKind.point, points, label);
    }
    if (letters.length == 2 && !isPlaneHint) {
      return _GeometryToken(_TokenKind.line, points, label);
    }
    return _GeometryToken(_TokenKind.plane, points, label);
  }

  /// Parses "khoảng cách từ/giữa <X> đến/tới/và <Y>" out of the (folded,
  /// lower-case) prompt and — once X and Y are resolved to a point, line,
  /// or plane by _resolveGeometryToken — builds the matching purple
  /// segment with a `d(X,Y) = value (giải thích)` label. This works for any
  /// point/line/plane pair the current solid's named vertices can express,
  /// which is what makes it apply to every problem instead of a handful of
  /// hardcoded textbook cases.
  _DistanceVisual? _parseDistanceRequest(
      String folded, Map<String, three.Vector3> vertices) {
    // "kho?ang" tolerates the common typo "khảng cách" (missing the "o")
    // that shows up when a problem is copy-pasted or OCR'd — without it,
    // one missing letter silently disabled the entire distance feature.
    final match = RegExp(
      r'kho?ang\s*cach\s*(?:tu|giua)?\s*(.+?)\s*(?:den|toi|voi|va)\s*(.+?)(?:[.,;]|$)',
    ).firstMatch(folded);
    if (match == null) return null;
    final x = _resolveGeometryToken(match.group(1)?.trim() ?? '', vertices);
    final y = _resolveGeometryToken(match.group(2)?.trim() ?? '', vertices);
    if (x == null || y == null) return null;
    return _buildDistanceVisual(x, y);
  }

  three.Vector3 _footOnLine(three.Vector3 p, three.Vector3 a, three.Vector3 b) {
    final ab = b.clone().sub(a);
    final len2 = ab.length2;
    if (len2 < 1e-9) return a;
    final t = p.clone().sub(a).dot(ab) / len2;
    return a.clone().add(ab.clone().scale(t));
  }

  three.Vector3 _footOnPlane(three.Vector3 p, List<three.Vector3> planePoints) {
    final a = planePoints[0];
    three.Vector3? normal;
    for (var i = 1; i + 1 < planePoints.length; i++) {
      final n = planePoints[i]
          .clone()
          .sub(a)
          .cross(planePoints[i + 1].clone().sub(a));
      if (n.length > 1e-6) {
        normal = n.normalize();
        break;
      }
    }
    normal ??= three.Vector3(0, 0, 1);
    final signed = p.clone().sub(a).dot(normal);
    return p.clone().sub(normal.clone().scale(signed));
  }

  /// Standard closest-points-between-two-(finite)-lines calculation, used
  /// for "khoảng cách giữa hai đường thẳng chéo nhau" style questions.
  (three.Vector3, three.Vector3) _closestPointsBetweenLines(
      three.Vector3 p1, three.Vector3 p2, three.Vector3 p3, three.Vector3 p4) {
    final d1 = p2.clone().sub(p1);
    final d2 = p4.clone().sub(p3);
    final r = p1.clone().sub(p3);
    final a = d1.dot(d1);
    final e = d2.dot(d2);
    final f = d2.dot(r);
    double s;
    double t;
    if (a < 1e-9 && e < 1e-9) {
      return (p1, p3);
    } else if (a < 1e-9) {
      s = 0;
      t = (f / e).clamp(0.0, 1.0);
    } else {
      final c = d1.dot(r);
      if (e < 1e-9) {
        t = 0;
        s = (-c / a).clamp(0.0, 1.0);
      } else {
        final b = d1.dot(d2);
        final denom = a * e - b * b;
        s = denom.abs() > 1e-9
            ? ((b * f - c * e) / denom).clamp(0.0, 1.0)
            : 0.0;
        t = ((b * s + f) / e).clamp(0.0, 1.0);
      }
    }
    final closest1 = p1.clone().add(d1.clone().scale(s));
    final closest2 = p3.clone().add(d2.clone().scale(t));
    return (closest1, closest2);
  }

  String _formatDistance(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    final rounded = (value * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(2);
  }

  _DistanceVisual? _buildDistanceVisual(_GeometryToken x, _GeometryToken y) {
    three.Vector3 start;
    three.Vector3 end;
    if (x.kind == _TokenKind.point && y.kind == _TokenKind.point) {
      start = x.points[0];
      end = y.points[0];
    } else if (x.kind == _TokenKind.point && y.kind == _TokenKind.line) {
      start = x.points[0];
      end = _footOnLine(x.points[0], y.points[0], y.points[1]);
    } else if (x.kind == _TokenKind.line && y.kind == _TokenKind.point) {
      start = y.points[0];
      end = _footOnLine(y.points[0], x.points[0], x.points[1]);
    } else if (x.kind == _TokenKind.point && y.kind == _TokenKind.plane) {
      start = x.points[0];
      end = _footOnPlane(x.points[0], y.points);
    } else if (x.kind == _TokenKind.plane && y.kind == _TokenKind.point) {
      start = y.points[0];
      end = _footOnPlane(y.points[0], x.points);
    } else if (x.kind == _TokenKind.plane && y.kind == _TokenKind.plane) {
      start = x.points[0];
      end = _footOnPlane(x.points[0], y.points);
    } else if (x.kind == _TokenKind.line && y.kind == _TokenKind.line) {
      final closest = _closestPointsBetweenLines(
          x.points[0], x.points[1], y.points[0], y.points[1]);
      start = closest.$1;
      end = closest.$2;
    } else if (x.kind == _TokenKind.line && y.kind == _TokenKind.plane) {
      start = x.points[0];
      end = _footOnPlane(x.points[0], y.points);
    } else if (x.kind == _TokenKind.plane && y.kind == _TokenKind.line) {
      start = y.points[0];
      end = _footOnPlane(y.points[0], x.points);
    } else {
      return null;
    }
    final distance = end.clone().sub(start).length;
    final unit = (widget.config.hasNumericMeasurements as bool)
        ? null
        : (widget.config.sceneUnitsPerA as num).toDouble();
    final valueText = unit != null && unit > 0
        ? '≈ ${_formatDistance(distance / unit)}a'
        : '≈ ${_formatDistance(distance)}';
    return _DistanceVisual(start, end, 'd(${x.label},${y.label}) = $valueText');
  }

  _DistanceVisual? _distanceVisual() {
    final folded = Math3DConfig.foldVietnamese(widget.config.title as String);
    if (!RegExp(r'kho?ang\s*cach').hasMatch(folded)) return null;
    final vertices = _allNamedVertices();
    if (vertices.isNotEmpty) {
      final generic = _parseDistanceRequest(folded, vertices);
      if (generic != null) return generic;
    }
    // Cylinder/cone (and anything else without named vertices): fall back
    // to the vertical axis, which is what "khoảng cách từ đỉnh/tâm đến mặt
    // đáy" means for these solids.
    final shape = _shapeName(widget.config.shape);
    if ((shape == 'cylinder' || shape == 'cone') &&
        (folded.contains('mat phang') ||
            folded.contains('day') ||
            folded.contains('truc'))) {
      final height = (widget.config.height as num).toDouble();
      return _DistanceVisual(
        three.Vector3(0, 0, height),
        three.Vector3(0, 0, 0),
        'd = ${_formatDistance(height)} (chiều cao / khoảng cách giữa hai đáy)',
      );
    }
    return null;
  }

  Map<String, three.Vector3> _cuboidPoints(
      double width, double depth, double height) {
    final x = width / 2;
    final y = depth / 2;
    return {
      'A': three.Vector3(-x, -y, 0),
      'B': three.Vector3(x, -y, 0),
      'C': three.Vector3(x, y, 0),
      'D': three.Vector3(-x, y, 0),
      "A'": three.Vector3(-x, -y, height),
      "B'": three.Vector3(x, -y, height),
      "C'": three.Vector3(x, y, height),
      "D'": three.Vector3(-x, y, height),
    };
  }

  void _addDistanceVisual(three.Object3D root, _DistanceVisual visual) {
    final vector = visual.end.clone().sub(visual.start);
    final length = vector.length;
    if (length < 0.001) return;
    final direction = vector.clone().normalize();
    final arrowLength = math.max(0.22, math.min(0.42, length * 0.22));
    final arrowWidth = arrowLength * 0.55;
    const purple = 0x8e44ad;
    root.add(helpers.ArrowHelper(
      direction,
      visual.start,
      length,
      purple,
      arrowLength,
      arrowWidth,
    ));
    root.add(helpers.ArrowHelper(
      direction.clone().negate(),
      visual.end,
      length,
      purple,
      arrowLength,
      arrowWidth,
    ));
  }

  List<_WorldLabel> _worldLabels() {
    final shape = _shapeName(widget.config.shape);
    final width = (widget.config.width as num).toDouble();
    final height =
        shape == 'cube' ? width : (widget.config.height as num).toDouble();
    final depth =
        shape == 'cube' ? width : (widget.config.depth as num).toDouble();
    final axisOffset = _isRectangularPyramid(widget.config) ? 16.0 : 7.0;
    final labels = <_WorldLabel>[
      _WorldLabel('O', three.Vector3(0, 0, 0), 0x586070, true, dx: -10, dy: 10),
      _WorldLabel('Ox', three.Vector3(5.8, 0, 0), 0xd84b5b, true,
          dx: axisOffset, dy: -8),
      _WorldLabel('Oy', three.Vector3(0, 5.8, 0), 0x2caa68, true,
          dx: axisOffset, dy: -8),
      _WorldLabel('Oz', three.Vector3(0, 0, 5.8), 0x3c78d8, true,
          dx: axisOffset, dy: -8),
    ];
    if (shape == 'frustum') {
      final bottomX = width / 2;
      final bottomY = depth / 2;
      final topX = (widget.config.topWidth as num).toDouble() / 2;
      final topY = (widget.config.topDepth as num).toDouble() / 2;
      final z = height;
      labels.addAll([
        _WorldLabel('A', three.Vector3(-bottomX, -bottomY, 0), 0x4d43af, false,
            dx: -14, dy: 8),
        _WorldLabel('B', three.Vector3(bottomX, -bottomY, 0), 0x4d43af, false,
            dx: 8, dy: 8),
        _WorldLabel('C', three.Vector3(bottomX, bottomY, 0), 0x4d43af, false,
            dx: 8, dy: -10),
        _WorldLabel('D', three.Vector3(-bottomX, bottomY, 0), 0x4d43af, false,
            dx: -14, dy: -10),
        _WorldLabel("A'", three.Vector3(-topX, -topY, z), 0x4d43af, false,
            dx: -16, dy: -12),
        _WorldLabel("B'", three.Vector3(topX, -topY, z), 0x4d43af, false,
            dx: 8, dy: -12),
        _WorldLabel("C'", three.Vector3(topX, topY, z), 0x4d43af, false,
            dx: 8, dy: 8),
        _WorldLabel("D'", three.Vector3(-topX, topY, z), 0x4d43af, false,
            dx: -16, dy: 8),
      ]);
    } else if (shape == 'cube' || shape == 'cuboid') {
      final x = width / 2;
      final y = depth / 2;
      final z = height;
      labels.addAll([
        _WorldLabel('A', three.Vector3(-x, -y, 0), 0x4d43af, false,
            dx: -14, dy: 8),
        _WorldLabel('B', three.Vector3(x, -y, 0), 0x4d43af, false,
            dx: 8, dy: 8),
        _WorldLabel('C', three.Vector3(x, y, 0), 0x4d43af, false,
            dx: 8, dy: -10),
        _WorldLabel('D', three.Vector3(-x, y, 0), 0x4d43af, false,
            dx: -14, dy: -10),
        _WorldLabel("A'", three.Vector3(-x, -y, z), 0x4d43af, false,
            dx: -16, dy: -12),
        _WorldLabel("B'", three.Vector3(x, -y, z), 0x4d43af, false,
            dx: 8, dy: -12),
        _WorldLabel("C'", three.Vector3(x, y, z), 0x4d43af, false,
            dx: 8, dy: 8),
        _WorldLabel("D'", three.Vector3(-x, y, z), 0x4d43af, false,
            dx: -16, dy: 8),
      ]);
    }
    final distance = _distanceVisual();
    if (distance != null) {
      final midpoint = distance.start.clone().lerp(distance.end, 0.5);
      labels.add(_WorldLabel(distance.label, midpoint, 0x8e44ad, false,
          dx: 8, dy: -8));
    }
    if (shape == 'pyramid' || shape == 'cone' || shape == 'tetrahedron') {
      if (_isRectangularPyramid(widget.config)) {
        final labels4 = _effectiveBaseLabels(4);
        final basePositions4 = [
          three.Vector3(-width / 2, -depth / 2, 0),
          three.Vector3(width / 2, -depth / 2, 0),
          three.Vector3(width / 2, depth / 2, 0),
          three.Vector3(-width / 2, depth / 2, 0),
        ];
        final apexIndex4 =
            (widget.config.apexBaseIndex as num).round().clamp(0, 3);
        final apexPos4 = basePositions4[apexIndex4];
        labels.addAll([
          _WorldLabel(labels4[0], basePositions4[0], 0x4d43af, false,
              dx: -14, dy: 8),
          _WorldLabel(labels4[1], basePositions4[1], 0x4d43af, false,
              dx: 8, dy: 8),
          _WorldLabel(labels4[2], basePositions4[2], 0x4d43af, false,
              dx: 8, dy: -10),
          _WorldLabel(labels4[3], basePositions4[3], 0x4d43af, false,
              dx: -16, dy: -12),
          _WorldLabel(_effectiveApexLabel,
              three.Vector3(apexPos4.x, apexPos4.y, height), 0x18a989, false,
              dx: 18, dy: -20),
        ]);
      } else if (_isRightTrapezoidPyramid(widget.config)) {
        final labels4 = _effectiveBaseLabels(4);
        final x = width / 2, z = depth / 2;
        final topWidth = (widget.config.topWidth as num).toDouble();
        final basePositionsT = [
          three.Vector3(-x, -z, 0), // A
          three.Vector3(x, -z, 0), // B
          three.Vector3(-x + topWidth, z, 0), // C
          three.Vector3(-x, z, 0), // D
        ];
        final apexIndexT =
            (widget.config.apexBaseIndex as num).round().clamp(0, 3);
        final apexPosT = basePositionsT[apexIndexT];
        labels.addAll([
          _WorldLabel(labels4[0], basePositionsT[0], 0x4d43af, false,
              dx: -14, dy: 8),
          _WorldLabel(labels4[1], basePositionsT[1], 0x4d43af, false,
              dx: 8, dy: 8),
          _WorldLabel(labels4[2], basePositionsT[2], 0x4d43af, false,
              dx: 8, dy: -10),
          _WorldLabel(labels4[3], basePositionsT[3], 0x4d43af, false,
              dx: -16, dy: -12),
          _WorldLabel(_effectiveApexLabel,
              three.Vector3(apexPosT.x, apexPosT.y, height), 0x18a989, false,
              dx: 18, dy: -20),
        ]);
      } else if (_isTriangularPyramid(widget.config)) {
        final labels3 = _effectiveBaseLabels(3);
        final basePositions3 = [
          three.Vector3(-width / 2, -depth / 2, 0),
          three.Vector3(width / 2, -depth / 2, 0),
          three.Vector3(width / 2, depth / 2, 0),
        ];
        final apexIndex3 =
            (widget.config.apexBaseIndex as num).round().clamp(0, 2);
        final apexPos3 = basePositions3[apexIndex3];
        labels.addAll([
          _WorldLabel(labels3[0], basePositions3[0], 0x4d43af, false,
              dx: -14, dy: 8),
          _WorldLabel(labels3[1], basePositions3[1], 0x4d43af, false,
              dx: 8, dy: 8),
          _WorldLabel(labels3[2], basePositions3[2], 0x4d43af, false,
              dx: 8, dy: -10),
          _WorldLabel(_effectiveApexLabel,
              three.Vector3(apexPos3.x, apexPos3.y, height), 0x18a989, false,
              dx: 8, dy: -14),
        ]);
      } else if (shape == 'pyramid' || shape == 'tetrahedron') {
        // Regular n-gon base (any n, e.g. "chóp thất giác đều"): label
        // every base vertex plus the apex, using the ACTUAL letters the
        // prompt named (e.g. F.APME) and the exact same vertex map the
        // geometry and the distance parser use.
        final n = (widget.config.sides as num).round().clamp(3, 24).toInt();
        final apexBaseIndex = (widget.config.apexBaseIndex as num).round();
        final apexLabel = _effectiveApexLabel;
        final vertices = _regularPyramidVertices(
            n, width, depth, height, apexBaseIndex,
            baseLabels: _effectiveBaseLabels(n), apexLabel: apexLabel);
        vertices.forEach((name, position) {
          final isApex = name == apexLabel;
          labels.add(_WorldLabel(
              name, position, isApex ? 0x18a989 : 0x4d43af, false,
              dx: isApex ? 12 : 6, dy: isApex ? -18 : 6));
        });
      } else {
        // Cone (not a pyramid): just mark the tip and the base centre.
        labels.add(_WorldLabel(
            'S', three.Vector3(0, 0, height), 0x18a989, false,
            dx: 8, dy: -14));
        labels.add(_WorldLabel(
            'A', three.Vector3(-width / 2, -depth / 2, 0), 0x4d43af, false,
            dx: -14, dy: 8));
      }
    } else if (shape == 'prism') {
      final vertices = widget.config.prismRightTriangleBase as bool
          ? _rightTrianglePrismVertices(width, depth, height,
              (widget.config.prismRightAngleIndex as num).round())
          : _prismVertices(
              (widget.config.sides as num).round().clamp(3, 24).toInt(),
              width,
              height);
      vertices.forEach((name, position) {
        // Height (world z) distinguishes top from bottom reliably even
        // when the prompt named the top face without primes (e.g. "O" for
        // "NID.OWP") — string-matching a trailing "'" only worked for the
        // conventional A,B,C.A',B',C' naming.
        final isTop = position.z > height / 2;
        labels.add(_WorldLabel(name, position, 0x4d43af, false,
            dx: isTop ? -14 : 6, dy: isTop ? -12 : 6));
      });
    }
    // Any point the prompt explicitly defines ("gọi H là trung điểm AC")
    // gets its own label too, in a distinct color from the solid's own
    // named vertices — drawn regardless of whether the question ends up
    // asking a distance about it.
    final rawVertices = _rawNamedVertices();
    if (rawVertices.isNotEmpty) {
      for (final entry in _definedAuxiliaryPoints(rawVertices).entries) {
        labels.add(_WorldLabel(entry.key, entry.value, 0xe0793c, false,
            dx: 10, dy: 6));
      }
    }
    return labels;
  }

  void _updateLabels() {
    if (!mounted || !_threeJs.mounted || _threeJs.screenSize == null) return;
    final next = <_ViewportLabel>[];
    for (final item in _worldLabels()) {
      final projected =
          three.Vector3.copy(item.position).project(_threeJs.camera);
      if (projected.z < -1 || projected.z > 1) continue;
      final viewportWidth =
          _viewportWidth > 0 ? _viewportWidth : _threeJs.width;
      final viewportHeight =
          _viewportHeight > 0 ? _viewportHeight : widget.height;
      final x = (projected.x + 1) * 0.5 * viewportWidth;
      final y = (1 - projected.y) * 0.5 * viewportHeight;
      if (x < -30 ||
          y < -20 ||
          x > viewportWidth + 30 ||
          y > viewportHeight + 20) continue;
      next.add(_ViewportLabel(
          item.text, x + item.dx, y + item.dy, item.color, item.axis));
    }
    _labels.value = next;
  }

  bool _isGroundedGeometry() {
    final shape = _shapeName(widget.config.shape);
    // Every pyramid variant (rectangle/triangle/regular n-gon), the
    // tetrahedron, and the prism (see _makeRegularPrism) are built with
    // their base at local y=0 and top at y=height, so they're all
    // "grounded" the same way a frustum is — no per-variant special
    // casing needed here.
    return shape == 'frustum' ||
        shape == 'pyramid' ||
        shape == 'tetrahedron' ||
        shape == 'prism';
  }

  String _shapeName(dynamic shape) => shape.toString().split('.').last;

  // NOTE: which kind of base a pyramid/tetrahedron has is decided ONCE, in
  // Math3DConfig.fromPrompt (see PyramidBaseKind), and carried on
  // config.pyramidBaseKind. Reading it here — instead of re-deriving it
  // from the title text with a second, independent regex — is what keeps
  // this file's geometry/labels in sync with math_3d_visuals.dart's
  // measurement inference and volume estimate.
  bool _isTriangularPyramid(dynamic config) {
    if (_shapeName(config.shape) != 'pyramid') return false;
    return (config.pyramidBaseKind as PyramidBaseKind) ==
        PyramidBaseKind.triangleRightAngle;
  }

  bool _isRectangularPyramid(dynamic config) {
    if (_shapeName(config.shape) != 'pyramid') return false;
    return (config.pyramidBaseKind as PyramidBaseKind) ==
        PyramidBaseKind.rectangle;
  }

  bool _isRightTrapezoidPyramid(dynamic config) {
    if (_shapeName(config.shape) != 'pyramid') return false;
    return (config.pyramidBaseKind as PyramidBaseKind) ==
        PyramidBaseKind.rightTrapezoid;
  }

  three.BufferGeometry _makeGeometry(dynamic config) {
    final width = math.max(0.2, (config.width as num).toDouble());
    final height = math.max(0.2, (config.height as num).toDouble());
    final depth = math.max(0.2, (config.depth as num).toDouble());
    final shape = _shapeName(config.shape);
    final sides = (config.sides as num).round();
    if (shape == 'cube') return three.BoxGeometry(width, width, width, 2, 2, 2);
    if (shape == 'cuboid')
      return three.BoxGeometry(width, height, depth, 2, 2, 2);
    if (shape == 'frustum') {
      final topWidth = math.max(0.2, (config.topWidth as num).toDouble());
      final topDepth = math.max(0.2, (config.topDepth as num).toDouble());
      return _makeFrustum(width, depth, topWidth, topDepth, height);
    }
    if (shape == 'pyramid') {
      final apexBaseIndex = (config.apexBaseIndex as num).round();
      if (_isTriangularPyramid(config))
        return _makeTriangularPyramid(
            width, depth, height, apexBaseIndex < 0 ? 0 : apexBaseIndex);
      if (_isRectangularPyramid(config))
        return _makeRectangularPyramid(
            width, depth, height, apexBaseIndex < 0 ? 0 : apexBaseIndex);
      if (_isRightTrapezoidPyramid(config)) {
        final topWidth = (config.topWidth as num).toDouble();
        return _makeRightTrapezoidPyramid(width, depth, topWidth, height,
            apexBaseIndex < 0 ? 0 : apexBaseIndex);
      }
      // Any other base — "chóp ngũ giác đều", "chóp thất giác đều", "chóp
      // 12 giác", or simply no polygon named — gets a proper regular n-gon
      // base (n = config.sides, any value from 3 to 24), apex centered
      // above the base unless a base vertex was requested (apexBaseIndex).
      final n = sides.clamp(3, 24).toInt();
      return _makeRegularPyramid(n, width, depth, height, apexBaseIndex);
    }
    if (shape == 'tetrahedron') {
      return _makeRegularPyramid(
          3, width, depth, height, (config.apexBaseIndex as num).round());
    }
    if (shape == 'prism') {
      if (config.prismRightTriangleBase as bool) {
        return _makeRightTrianglePrism(
            width, depth, height, (config.prismRightAngleIndex as num).round());
      }
      // Built with the exact same _regularPolygonBaseLocal formula as
      // _prismVertices (labels/distance line) — CylinderGeometry uses its
      // own internal angle convention, which doesn't match ours and was
      // making the purple line and vertex labels land off the actual
      // rendered faces (the solid looked "skewed").
      return _makeRegularPrism(sides.clamp(3, 24).toInt(), width, height);
    }
    if (shape == 'cylinder') {
      return three.CylinderGeometry(
          width / 2, width / 2, height, math.max(24, sides), 2);
    }
    if (shape == 'cone')
      return three.ConeGeometry(width / 2, height, math.max(24, sides), 2);
    if (shape == 'sphere') {
      return three.SphereGeometry(
          width / 2, math.max(24, sides), math.max(16, sides ~/ 2));
    }
    return three.BoxGeometry(width, depth, 0.06, 1, 1, 1);
  }

  three.BufferGeometry _makeFrustum(double width, double depth, double topWidth,
      double topDepth, double height) {
    final geometry = three.BufferGeometry();
    final vertices = <double>[
      -width / 2,
      0,
      depth / 2,
      width / 2,
      0,
      depth / 2,
      width / 2,
      0,
      -depth / 2,
      -width / 2,
      0,
      -depth / 2,
      -topWidth / 2,
      height,
      topDepth / 2,
      topWidth / 2,
      height,
      topDepth / 2,
      topWidth / 2,
      height,
      -topDepth / 2,
      -topWidth / 2,
      height,
      -topDepth / 2,
    ];
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(vertices, 3, false),
    );
    geometry.setIndex(<int>[
      0,
      1,
      2,
      0,
      2,
      3,
      4,
      6,
      5,
      4,
      7,
      6,
      0,
      4,
      5,
      0,
      5,
      1,
      1,
      5,
      6,
      1,
      6,
      2,
      2,
      6,
      7,
      2,
      7,
      3,
      3,
      7,
      4,
      3,
      4,
      0,
    ]);
    geometry.computeVertexNormals();
    return geometry;
  }

  three.BufferGeometry _makeRectangularPyramid(
      double width, double depth, double height, int apexBaseIndex) {
    final x = width / 2;
    final y = depth / 2;
    final base = <List<double>>[
      [-x, 0, y], // A
      [x, 0, y], // B
      [x, 0, -y], // C
      [-x, 0, -y], // D
    ];
    final apex = base[apexBaseIndex.clamp(0, 3)];
    final geometry = three.BufferGeometry();
    final vertices = <double>[
      ...base[0], ...base[1], ...base[2], ...base[3],
      apex[0], height, apex[2], // apex directly above the chosen base vertex
    ];
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(vertices, 3, false),
    );
    geometry.setIndex(<int>[
      0,
      3,
      2,
      0,
      2,
      1,
      0,
      1,
      4,
      1,
      2,
      4,
      2,
      3,
      4,
      3,
      0,
      4,
    ]);
    geometry.computeVertexNormals();
    return geometry;
  }

  /// Right trapezoid base: AB ∥ DC, right angles at A and D — e.g. "đáy
  /// ABCD là hình thang vuông tại A và D". `width` = AB, `depth` = AD (the
  /// perpendicular leg), `topWidth` = DC. Matched exactly by
  /// _rawNamedVertices' rightTrapezoid branch for labels/distance lines.
  three.BufferGeometry _makeRightTrapezoidPyramid(double width, double depth,
      double topWidth, double height, int apexBaseIndex) {
    final x = width / 2;
    final z = depth / 2;
    final base = <List<double>>[
      [-x, 0, z], // A
      [x, 0, z], // B
      [-x + topWidth, 0, -z], // C
      [-x, 0, -z], // D
    ];
    final apex = base[apexBaseIndex.clamp(0, 3)];
    final geometry = three.BufferGeometry();
    final vertices = <double>[
      ...base[0],
      ...base[1],
      ...base[2],
      ...base[3],
      apex[0],
      height,
      apex[2],
    ];
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(vertices, 3, false),
    );
    geometry.setIndex(<int>[
      0, 3, 2, 0, 2, 1, // base (A-D-C, A-C-B)
      0, 1, 4, // ABS
      1, 2, 4, // BCS
      2, 3, 4, // CDS
      3, 0, 4, // DAS
    ]);
    geometry.computeVertexNormals();
    return geometry;
  }

  three.BufferGeometry _makeTriangularPyramid(
      double width, double depth, double height, int apexBaseIndex) {
    // Local Y is the height direction; the common mesh rotation below maps it to world Z.
    // The apex sits directly above whichever base vertex the prompt named
    // as perpendicular (index 0/A by default, but can be any of the 3).
    final x = width / 2;
    final y = depth / 2;
    final base = <List<double>>[
      [-x, 0, y], // A
      [x, 0, y], // B
      [x, 0, -y], // C
    ];
    final apex = base[apexBaseIndex.clamp(0, 2)];
    final geometry = three.BufferGeometry();
    final vertices = <double>[
      ...base[0],
      ...base[1],
      ...base[2],
      apex[0],
      height,
      apex[2],
    ];
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(vertices, 3, false),
    );
    geometry.setIndex(<int>[
      0, 2, 1, // ABC
      0, 1, 3, // ABS
      1, 2, 3, // BCS
      2, 0, 3, // CAS
    ]);
    geometry.computeVertexNormals();
    return geometry;
  }

  /// Local (x, z) offsets of the n base vertices of a regular polygon whose
  /// EDGE LENGTH is `width`/`depth` (not the circumscribed diameter — a
  /// regular n-gon's edge is shorter than its diameter for every n, e.g.
  /// only ≈0.87× for a triangle, so treating width as the diameter drew
  /// every "cạnh đáy bằng a" polygon noticeably smaller than a). `depth`
  /// lets width/depth differ slightly for an irregular-base approximation;
  /// pass the same value for both for a true regular polygon (the normal
  /// case). This is the single formula used to build the base of ANY
  /// n-sided pyramid or prism — and, matched exactly, to compute where
  /// their named vertices sit in world space for labels and the purple
  /// distance line (see _regularPyramidVertices below).
  List<Offset> _regularPolygonBaseLocal(int n, double width, double depth) {
    final halfAngle = math.pi / n;
    final rx = width / (2 * math.sin(halfAngle));
    final ry = depth / (2 * math.sin(halfAngle));
    return List<Offset>.generate(n, (i) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      return Offset(rx * math.cos(angle), ry * math.sin(angle));
    });
  }

  /// A regular n-sided pyramid: n base vertices (local y=0) + one apex
  /// (local y=height), either centered above the base ("chóp đều") or
  /// above a chosen base vertex (apexBaseIndex >= 0, e.g. "SA vuông góc").
  /// Works for any n from 3 up — this is what makes an arbitrary "hình chóp
  /// <n>-giác đều" buildable instead of only 3- and 4-sided special cases.
  three.BufferGeometry _makeRegularPyramid(
      int n, double width, double depth, double height, int apexBaseIndex) {
    final baseLocal = _regularPolygonBaseLocal(n, width, depth);
    final vertices = <double>[];
    for (final v in baseLocal) {
      vertices.addAll([v.dx, 0, v.dy]);
    }
    final apexLocal = apexBaseIndex >= 0 && apexBaseIndex < n
        ? baseLocal[apexBaseIndex]
        : Offset.zero;
    vertices.addAll([apexLocal.dx, height, apexLocal.dy]);

    final geometry = three.BufferGeometry();
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(vertices, 3, false),
    );
    final apexIndex = n;
    final indices = <int>[];
    // Base fan.
    for (var i = 1; i < n - 1; i++) {
      indices.addAll([0, i + 1, i]);
    }
    // Side faces.
    for (var i = 0; i < n; i++) {
      final next = (i + 1) % n;
      indices.addAll([i, next, apexIndex]);
    }
    geometry.setIndex(indices);
    geometry.computeVertexNormals();
    return geometry;
  }

  /// Named vertices (base letters + apex) of a regular n-sided pyramid, in
  /// WORLD space — built with the exact same formula as _makeRegularPyramid
  /// so labels and the purple distance line always land exactly on the
  /// rendered solid's corners. World mapping: the mesh applies
  /// rotation.x = π/2, which sends local (x, y, z) -> world (x, -z, y).
  /// `baseLabels`/`apexLabel` default to the conventional A, B, C.../S, but
  /// pass the actual letters the prompt named (e.g. F.APME) when known.
  Map<String, three.Vector3> _regularPyramidVertices(
      int n, double width, double depth, double height, int apexBaseIndex,
      {List<String>? baseLabels, String apexLabel = 'S'}) {
    final baseLocal = _regularPolygonBaseLocal(n, width, depth);
    final labels = (baseLabels != null && baseLabels.length == n)
        ? baseLabels
        : _polygonLetters.sublist(0, n.clamp(0, _polygonLetters.length));
    final map = <String, three.Vector3>{};
    for (var i = 0; i < n && i < labels.length; i++) {
      final local = baseLocal[i];
      map[labels[i]] = three.Vector3(local.dx, -local.dy, 0);
    }
    final apexLocal = apexBaseIndex >= 0 && apexBaseIndex < n
        ? baseLocal[apexBaseIndex]
        : Offset.zero;
    map[apexLabel] = three.Vector3(apexLocal.dx, -apexLocal.dy, height);
    return map;
  }

  /// A right-triangle-base prism: legs (from the right-angle vertex) can
  /// differ, e.g. "đáy ABC là tam giác vuông tại A, AB=a, AC=2a" — unlike
  /// _makeRegularPrism, which forces every base edge equal. `width` is the
  /// leg to the numerically-smaller of the two OTHER base indices, `depth`
  /// the leg to the larger — matching _rightTrianglePrismVertices exactly.
  three.BufferGeometry _makeRightTrianglePrism(
      double width, double depth, double height, int rightAngleIndex) {
    final ra = rightAngleIndex.clamp(0, 2);
    final others = [0, 1, 2].where((i) => i != ra).toList(growable: false);
    final local = <int, List<double>>{
      ra: [0.0, 0.0],
      others[0]: [width, 0.0],
      others[1]: [0.0, depth],
    };
    final vertices = <double>[];
    for (var i = 0; i < 3; i++) {
      final p = local[i]!;
      vertices.addAll([p[0], 0, p[1]]);
    }
    for (var i = 0; i < 3; i++) {
      final p = local[i]!;
      vertices.addAll([p[0], height, p[1]]);
    }
    final geometry = three.BufferGeometry();
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(vertices, 3, false),
    );
    const top = 3;
    geometry.setIndex(<int>[
      0, 2, 1, // bottom
      top, top + 1, top + 2, // top
      0, 1, top + 1, 0, top + 1, top, // side 0-1
      1, 2, top + 2, 1, top + 2, top + 1, // side 1-2
      2, 0, top, 2, top, top + 2, // side 2-0
    ]);
    geometry.computeVertexNormals();
    return geometry;
  }

  /// Named vertices of a right-triangle-base prism, using the SAME local
  /// layout as _makeRightTrianglePrism so labels/distance lines land
  /// exactly on the rendered solid.
  Map<String, three.Vector3> _rightTrianglePrismVertices(
      double width, double depth, double height, int rightAngleIndex) {
    final ra = rightAngleIndex.clamp(0, 2);
    final others = [0, 1, 2].where((i) => i != ra).toList(growable: false);
    final local = <int, List<double>>{
      ra: [0.0, 0.0],
      others[0]: [width, 0.0],
      others[1]: [0.0, depth],
    };
    final bottomLabels = _effectiveBaseLabels(3);
    final topCustom = (widget.config.topLabels as List).cast<String>();
    final topLabels = topCustom.length == 3
        ? topCustom
        : bottomLabels.map((letter) => "$letter'").toList();
    final map = <String, three.Vector3>{};
    for (var i = 0; i < 3; i++) {
      final p = local[i]!;
      map[bottomLabels[i]] = three.Vector3(p[0], -p[1], 0);
      map[topLabels[i]] = three.Vector3(p[0], -p[1], height);
    }
    return map;
  }

  /// An n-sided prism built from the SAME _regularPolygonBaseLocal formula
  /// as _prismVertices, so the mesh, the vertex labels, and the purple
  /// distance line always agree on where each corner is. Local y=0 is the
  /// bottom face (A, B, C, ...), local y=height is the top face
  /// (A', B', C', ...).
  three.BufferGeometry _makeRegularPrism(int n, double width, double height) {
    final baseLocal = _regularPolygonBaseLocal(n, width, width);
    final vertices = <double>[];
    for (final v in baseLocal) {
      vertices.addAll([v.dx, 0, v.dy]);
    }
    for (final v in baseLocal) {
      vertices.addAll([v.dx, height, v.dy]);
    }
    final geometry = three.BufferGeometry();
    geometry.setAttributeFromString(
      'position',
      three.Float32BufferAttribute.fromList(vertices, 3, false),
    );
    final top = n;
    final indices = <int>[];
    // Bottom fan, top fan.
    for (var i = 1; i < n - 1; i++) {
      indices.addAll([0, i + 1, i]);
    }
    for (var i = 1; i < n - 1; i++) {
      indices.addAll([top, top + i, top + i + 1]);
    }
    // Side quads (two triangles each).
    for (var i = 0; i < n; i++) {
      final next = (i + 1) % n;
      indices.addAll([i, next, top + next]);
      indices.addAll([i, top + next, top + i]);
    }
    geometry.setIndex(indices);
    geometry.computeVertexNormals();
    return geometry;
  }

  /// Named vertices of an n-sided prism (bottom + top faces), using the
  /// ACTUAL letters the prompt named — e.g. bottom ["N","I","D"] and top
  /// ["O","W","P"] for "NID.OWP" — falling back to the conventional
  /// A, B, C... / A', B', C'... when the prompt didn't name it explicitly.
  Map<String, three.Vector3> _prismVertices(
      int n, double width, double height) {
    final baseLocal = _regularPolygonBaseLocal(n, width, width);
    final bottomCustom = (widget.config.baseLabels as List).cast<String>();
    final topCustom = (widget.config.topLabels as List).cast<String>();
    final bottomLabels = bottomCustom.length == n
        ? bottomCustom
        : _polygonLetters.sublist(0, n.clamp(0, _polygonLetters.length));
    final topLabels = topCustom.length == n
        ? topCustom
        : bottomLabels.map((letter) => "$letter'").toList();
    final map = <String, three.Vector3>{};
    for (var i = 0; i < n && i < bottomLabels.length; i++) {
      final local = baseLocal[i];
      map[bottomLabels[i]] = three.Vector3(local.dx, -local.dy, 0);
      map[topLabels[i]] = three.Vector3(local.dx, -local.dy, height);
    }
    return map;
  }

  int _materialColor(dynamic shape) {
    return switch (_shapeName(shape)) {
      'cube' || 'cuboid' => 0x7568df,
      'pyramid' || 'tetrahedron' => 0x18b99a,
      'prism' => 0x4e9de5,
      'cylinder' || 'cone' => 0xf1a83b,
      'sphere' => 0xc36be8,
      _ => 0x9a92e8,
    };
  }

  double _objectHeight() {
    final shape = _shapeName(widget.config.shape);
    if (shape == 'cube' || shape == 'sphere')
      return (widget.config.width as num).toDouble();
    return math.max(0.2, (widget.config.height as num).toDouble());
  }

  double _targetHeight() => _objectHeight() * 0.48;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        _viewportHeight = widget.height;
        if (_threeJs.mounted) {
          final aspect = _viewportWidth / math.max(1, _viewportHeight);
          if ((_threeJs.camera as three.PerspectiveCamera).aspect != aspect) {
            (_threeJs.camera as three.PerspectiveCamera).aspect = aspect;
            (_threeJs.camera as three.PerspectiveCamera)
                .updateProjectionMatrix();
          }
        }
        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _threeJs.build(),
                ValueListenableBuilder<List<_ViewportLabel>>(
                  valueListenable: _labels,
                  builder: (context, labels, child) {
                    return IgnorePointer(
                      child: Stack(
                        children: labels.map((label) {
                          return Positioned(
                            left: label.x - (label.axis ? 4 : 7),
                            top: label.y - (label.axis ? 8 : 10),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 1),
                                child: Text(
                                  label.text,
                                  style: TextStyle(
                                    color: Color(0xFF000000 | label.color),
                                    fontSize: label.axis ? 11 : 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text(
                            'Kéo chuột trái: xoay · Kéo chuột giữa: phóng to/thu nhỏ · Kéo chuột phải: di chuyển',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
