import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Pages flip over the spine (the left edge) like a book, registered once in the app theme so every route shares it.
/// Forward: the current page curls up from its free edge and flips over the spine, uncovering the new page.
/// Back: the previous page flips back over the spine and settles flat onto the current one.
/// Geometry and lighting follow flipbook-vue as ported in flutter_realistic_flipbook (MIT); the flipping leaf is a
/// snapshot of the page drawn as a bent mesh, so the page itself is not rebuilt per frame.
class BookPageTransitionsBuilder extends PageTransitionsBuilder {
  const BookPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 800);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return _PageFlip(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      paper: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}

class _PageFlip extends StatefulWidget {
  const _PageFlip({
    required this.animation,
    required this.secondaryAnimation,
    required this.paper,
    required this.child,
  });

  // A route hands its transitions the same two animations for its whole life, so they are read once.
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Color paper;
  final Widget child;

  @override
  State<_PageFlip> createState() => _PageFlipState();
}

class _PageFlipState extends State<_PageFlip> {
  final _snapshot = SnapshotController();
  late final _painter = _FlipPainter(
    widget.animation,
    widget.secondaryAnimation,
    widget.paper,
  )..addListener(_update);

  // Only the flipping leaf needs the snapshot; otherwise the page paints live.
  void _update() =>
      _snapshot.allowSnapshotting = !widget.secondaryAnimation.isDismissed;

  @override
  void didUpdateWidget(_PageFlip old) {
    super.didUpdateWidget(old);
    _painter.paper = widget.paper;
  }

  @override
  void dispose() {
    _painter.dispose();
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SnapshotWidget(
    controller: _snapshot,
    mode: SnapshotMode.permissive,
    painter: _painter,
    child: widget.child,
  );
}

/// The navigator paints a new route above the old one, so in both directions the old (lower) route draws the leaf
/// and the new (upper) route shows only the part of itself the leaf is not covering. Both read the same controller,
/// so they stay in step, and back is the same flip played in reverse.
class _FlipPainter extends SnapshotPainter {
  _FlipPainter(this.enter, this.cover, this.paper) {
    enter.addListener(notifyListeners);
    cover.addListener(notifyListeners);
  }

  /// This route's own push or pop: it is the upper page.
  final Animation<double> enter;

  /// A route pushed onto or popped off this one: this is the leaf.
  final Animation<double> cover;
  Color paper;

  static PageFlip _leaf(Size size, Animation<double> a) =>
      PageFlip(size, Curves.easeInOut.transform(a.value));

  @override
  void paint(
    PaintingContext context,
    Offset offset,
    Size size,
    PaintingContextCallback painter,
  ) {
    if (enter.isCompleted) return painter(context, offset);
    final leaf = _leaf(size, enter);
    final open = Rect.fromLTRB(leaf.edge, 0, size.width, size.height);
    context.pushClipRect(true, offset, open, (context, offset) {
      painter(context, offset);
      leaf.paintShadow(context.canvas, offset);
    });
  }

  @override
  void paintSnapshot(
    PaintingContext context,
    Offset offset,
    Size size,
    ui.Image image,
    Size sourceSize,
    double pixelRatio,
  ) => _leaf(
    size,
    cover,
  ).paintLeaf(context.canvas, offset, image, pixelRatio, paper);

  @override
  bool shouldRepaint(_FlipPainter oldPainter) => true;

  @override
  void dispose() {
    enter.removeListener(notifyListeners);
    cover.removeListener(notifyListeners);
    super.dispose();
  }
}

/// A leaf hinged at the spine (left edge), [progress] of the way through a flip (0 flat on the page, 1 turned over).
/// First half: the free edge curls up toward the viewer until the leaf is a half roll. Second half: the roll swings
/// over the spine while unrolling.
@visibleForTesting
class PageFlip {
  PageFlip(this.size, this.progress) {
    final width = size.width;
    final theta = max(
      progress < 0.5 ? progress * 2 * pi : (2 - progress * 2) * pi,
      1e-9,
    );
    final radius = width / theta;
    final swing = progress > 0.5 ? (progress - 0.5) * 2 * pi : 0.0;
    final camera = width * 6;
    for (var i = 0; i <= _columns; i++) {
      final bend = theta * i / _columns;
      final x = sin(bend) * radius, z = (1 - cos(bend)) * radius;
      final x2 = x * cos(swing) - z * sin(swing),
          z2 = x * sin(swing) + z * cos(swing);
      _angle.add(bend + swing);
      _scale.add(camera / (camera - z2));
      _x.add(width / 2 + (x2 - width / 2) * _scale.last);
    }
    edge = _x.reduce(max).clamp(0, width);
  }

  final Size size;
  final double progress;

  /// The right-most screen x the leaf covers; the page beneath shows right of it.
  late final double edge;

  static const _columns = 48;
  static const _ambient = 0.4;
  static const _gloss = 0.6;

  /// Per column, spine to free edge: how far the paper has turned from flat, its depth scale, and screen x.
  final _angle = <double>[], _scale = <double>[], _x = <double>[];

  Offset _project(int column, double y) => Offset(
    _x[column],
    size.height / 2 + (y - size.height / 2) * _scale[column],
  );

  /// Where page point [p] lands on screen.
  Offset land(Offset p) =>
      _project((p.dx / size.width * _columns).round().clamp(0, _columns), p.dy);

  /// The leaf's shadow on the page it uncovers, strongest mid-flip.
  void paintShadow(Canvas canvas, Offset offset) {
    final band = Rect.fromLTWH(offset.dx + edge, offset.dy, 64, size.height);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.35 * sin(pi * progress)),
            Colors.transparent,
          ],
        ).createShader(band),
    );
  }

  /// The page [image] bent along the flip, shaded and glossed by how each strip faces the viewer, with the paper's
  /// back (faint show-through ink) where it faces up.
  void paintLeaf(
    Canvas canvas,
    Offset offset,
    ui.Image image,
    double pixelRatio,
    Color paper,
  ) {
    const rows = 16;
    final points = <Offset>[],
        texture = <Offset>[],
        shade = <Color>[],
        gloss = <Color>[];
    for (var j = 0; j <= rows; j++) {
      final y = size.height * j / rows;
      for (var i = 0; i <= _columns; i++) {
        // The face toward the viewer: the front until the paper passes edge-on, then the back.
        final facing = cos(_angle[i]).abs();
        final tilt = acos(facing);
        final shine = max(
          pow(cos(tilt + pi / 6), 200),
          pow(cos(tilt - pi / 6), 200),
        ).toDouble();
        points.add(_project(i, y));
        texture.add(Offset(size.width * i / _columns, y));
        shade.add(
          Colors.black.withValues(alpha: (1 - facing) * (1 - _ambient)),
        );
        gloss.add(Colors.white.withValues(alpha: shine * _gloss));
      }
    }
    // Spine to free edge is far to near while the leaf curls, so later strips rightly cover earlier ones.
    final front = <int>[], rear = <int>[];
    for (var i = 0; i < _columns; i++) {
      final side = cos((_angle[i] + _angle[i + 1]) / 2) < 0 ? rear : front;
      for (var j = 0; j < rows; j++) {
        final a = j * (_columns + 1) + i,
            b = a + 1,
            c = a + _columns + 1,
            d = c + 1;
        side.addAll([a, b, c, b, d, c]);
      }
    }
    final page = Paint()
      ..filterQuality = FilterQuality.low
      ..shader = ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.diagonal3Values(1 / pixelRatio, 1 / pixelRatio, 1).storage,
      );
    ui.Vertices mesh(List<int> indices, [List<Color>? colors]) => ui.Vertices(
      VertexMode.triangles,
      points,
      textureCoordinates: colors == null ? texture : null,
      colors: colors,
      indices: indices,
    );
    // Texture and light are separate passes: mixing vertex colours into a textured mesh leaves seams on some
    // renderers.
    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    for (final side in [front, rear]) {
      if (side.isEmpty) continue;
      canvas.drawVertices(mesh(side), BlendMode.src, page);
      // The back of the page: paper, with the ink from the front faintly showing through.
      if (identical(side, rear)) {
        canvas.drawVertices(
          mesh(side, List.filled(points.length, paper.withValues(alpha: 0.86))),
          BlendMode.dst,
          Paint(),
        );
      }
      canvas
        ..drawVertices(mesh(side, shade), BlendMode.dst, Paint())
        ..drawVertices(mesh(side, gloss), BlendMode.dst, Paint());
    }
    canvas.restore();
  }
}
