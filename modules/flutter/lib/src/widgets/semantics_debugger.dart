// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the CHROMIUM_LICENSE file.

import 'dart:math' as math;
import 'package:canvas_ui/canvas_ui.dart' show SemanticsFlags;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'binding.dart';
import 'framework.dart';
import 'gesture_detector.dart';

/// A widget that visualizes the semantics for the child.
///
/// This widget is useful for understand how an app presents itself to
/// accessibility technology.
class SemanticsDebugger extends StatefulWidget {
  /// Creates a widget that visualizes the semantics for the child.
  ///
  /// The [child] argument must not be null.
  const SemanticsDebugger({ Key key, this.child }) : super(key: key);

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  _SemanticsDebuggerState createState() => new _SemanticsDebuggerState();
}

class _SemanticsDebuggerState extends State<SemanticsDebugger> {
  _SemanticsClient _client;

  @override
  void initState() {
    super.initState();
    // TODO(abarth): We shouldn't reach out to the WidgetsBinding.instance
    // static here because we might not be in a tree that's attached to that
    // binding. Instead, we should find a way to get to the PipelineOwner from
    // the BuildContext.
    _client = new _SemanticsClient(WidgetsBinding.instance.pipelineOwner)
      ..addListener(_update);
  }

  @override
  void dispose() {
    _client
      ..removeListener(_update)
      ..dispose();
    super.dispose();
  }

  void _update() {
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      // We want the update to take effect next frame, so to make that
      // explicit we call setState() in a post-frame callback.
      if (mounted) {
        // If we got disposed this frame, we will still get an update,
        // because the inactive list is flushed after the semantics updates
        // are transmitted to the semantics clients.
        setState(() {
          // The generation of the _SemanticsDebuggerListener has changed.
        });
      }
    });
  }

  Point _lastPointerDownLocation;
  void _handlePointerDown(PointerDownEvent event) {
    setState(() {
      _lastPointerDownLocation = event.position;
    });
  }

  void _handleTap() {
    assert(_lastPointerDownLocation != null);
    _performAction(_lastPointerDownLocation, SemanticsAction.tap);
    setState(() {
      _lastPointerDownLocation = null;
    });
  }

  void _handleLongPress() {
    assert(_lastPointerDownLocation != null);
    _performAction(_lastPointerDownLocation, SemanticsAction.longPress);
    setState(() {
      _lastPointerDownLocation = null;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    double vx = details.velocity.pixelsPerSecond.dx;
    double vy = details.velocity.pixelsPerSecond.dy;
    if (vx.abs() == vy.abs())
      return;
    if (vx.abs() > vy.abs()) {
      if (vx.sign < 0) {
        _performAction(_lastPointerDownLocation, SemanticsAction.decrease);
        _performAction(_lastPointerDownLocation, SemanticsAction.scrollLeft);
      } else {
        _performAction(_lastPointerDownLocation, SemanticsAction.increase);
        _performAction(_lastPointerDownLocation, SemanticsAction.scrollRight);
      }
    } else {
      if (vy.sign < 0)
        _performAction(_lastPointerDownLocation, SemanticsAction.scrollUp);
      else
        _performAction(_lastPointerDownLocation, SemanticsAction.scrollDown);
    }
    setState(() {
      _lastPointerDownLocation = null;
    });
  }

  void _performAction(Point position, SemanticsAction action) {
    _pipelineOwner.semanticsOwner?.performActionAt(position, action);
  }

  // TODO(abarth): This shouldn't be a static. We should get the pipeline owner
  // from [context] somehow.
  PipelineOwner get _pipelineOwner => WidgetsBinding.instance.pipelineOwner;

  @override
  Widget build(BuildContext context) {
    return new CustomPaint(
      foregroundPainter: new _SemanticsDebuggerPainter(
        _pipelineOwner,
        _client.generation,
        _lastPointerDownLocation
      ),
      child: new GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onLongPress: _handleLongPress,
        onPanEnd: _handlePanEnd,
        excludeFromSemantics: true, // otherwise if you don't hit anything, we end up receiving it, which causes an infinite loop...
        child: new Listener(
          onPointerDown: _handlePointerDown,
          behavior: HitTestBehavior.opaque,
          child: new IgnorePointer(
            ignoringSemantics: false,
            child: config.child
          )
        )
      )
    );
  }
}

class _SemanticsClient extends ChangeNotifier {
  _SemanticsClient(PipelineOwner pipelineOwner) {
    _semanticsHandle = pipelineOwner.ensureSemantics(
      listener: _didUpdateSemantics
    );
  }

  SemanticsHandle _semanticsHandle;

  @override
  void dispose() {
    _semanticsHandle.dispose();
    _semanticsHandle = null;
    super.dispose();
  }

  int generation = 0;

  void _didUpdateSemantics() {
    generation += 1;
    notifyListeners();
  }
}

String _getMessage(SemanticsNode node) {
  SemanticsData data = node.getSemanticsData();
  List<String> annotations = <String>[];

  bool wantsTap = false;
  if (data.hasFlag(SemanticsFlags.hasCheckedState)) {
    annotations.add(data.hasFlag(SemanticsFlags.isChecked) ? 'checked' : 'unchecked');
    wantsTap = true;
  }

  if (data.hasAction(SemanticsAction.tap)) {
    if (!wantsTap)
      annotations.add('button');
  } else {
    if (wantsTap)
      annotations.add('disabled');
  }

  if (data.hasAction(SemanticsAction.longPress))
    annotations.add('long-pressable');

  final bool isScrollable = data.hasAction(SemanticsAction.scrollLeft)
                         || data.hasAction(SemanticsAction.scrollRight)
                         || data.hasAction(SemanticsAction.scrollUp)
                         || data.hasAction(SemanticsAction.scrollDown);

  final bool isAdjustable = data.hasAction(SemanticsAction.increase)
                         || data.hasAction(SemanticsAction.decrease);

  if (isScrollable)
    annotations.add('scrollable');

  if (isAdjustable)
    annotations.add('adjustable');

  String message;
  if (annotations.isEmpty) {
    assert(data.label != null);
    message = data.label;
  } else {
    if (data.label.isEmpty) {
      message = annotations.join('; ');
    } else {
      message = '${data.label} (${annotations.join('; ')})';
    }
  }

  return message.trim();
}

const TextStyle _messageStyle = const TextStyle(
  color: const Color(0xFF000000),
  fontSize: 10.0,
  height: 0.8
);

void _paintMessage(Canvas canvas, SemanticsNode node) {
  String message = _getMessage(node);
  if (message.isEmpty)
    return;
  final Rect rect = node.rect;
  canvas.save();
  canvas.clipRect(rect);
  TextPainter textPainter = new TextPainter()
    ..text = new TextSpan(style: _messageStyle, text: message)
    ..layout(maxWidth: rect.width);

  textPainter.paint(canvas, FractionalOffset.center.inscribe(textPainter.size, rect).topLeft.toOffset());
  canvas.restore();
}

int _findDepth(SemanticsNode node) {
  if (!node.hasChildren || node.mergeAllDescendantsIntoThisNode)
    return 1;
  int childrenDepth = 0;
  node.visitChildren((SemanticsNode child) {
    childrenDepth = math.max(childrenDepth, _findDepth(child));
    return true;
  });
  return childrenDepth + 1;
}

void _paint(Canvas canvas, SemanticsNode node, int rank) {
  canvas.save();
  if (node.transform != null)
    canvas.transform(node.transform.storage);
  Rect rect = node.rect;
  if (!rect.isEmpty) {
    Color lineColor = new Color(0xFF000000 + new math.Random(node.id).nextInt(0xFFFFFF));
    Rect innerRect = rect.deflate(rank * 1.0);
    if (innerRect.isEmpty) {
      Paint fill = new Paint()
       ..color = lineColor
       ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fill);
    } else {
      Paint fill = new Paint()
       ..color = const Color(0xFFFFFFFF)
       ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fill);
      Paint line = new Paint()
       ..strokeWidth = rank * 2.0
       ..color = lineColor
       ..style = PaintingStyle.stroke;
      canvas.drawRect(innerRect, line);
    }
    _paintMessage(canvas, node);
  }
  if (!node.mergeAllDescendantsIntoThisNode) {
    final int childRank = rank - 1;
    node.visitChildren((SemanticsNode child) {
      _paint(canvas, child, childRank);
      return true;
    });
  }
  canvas.restore();
}

class _SemanticsDebuggerPainter extends CustomPainter {
  const _SemanticsDebuggerPainter(this.owner, this.generation, this.pointerPosition);

  final PipelineOwner owner;
  final int generation;
  final Point pointerPosition;

  SemanticsNode get _rootSemanticsNode {
    return owner.semanticsOwner?.rootSemanticsNode;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final SemanticsNode rootNode = _rootSemanticsNode;
    if (rootNode != null)
      _paint(canvas, rootNode, _findDepth(rootNode));
    if (pointerPosition != null) {
      Paint paint = new Paint();
      paint.color = const Color(0x7F0090FF);
      canvas.drawCircle(pointerPosition, 10.0, paint);
    }
  }

  @override
  bool shouldRepaint(_SemanticsDebuggerPainter oldDelegate) {
    return owner != oldDelegate.owner
        || generation != oldDelegate.generation
        || pointerPosition != oldDelegate.pointerPosition;
  }
}