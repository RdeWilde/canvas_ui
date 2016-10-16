// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the CHROMIUM_LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:test/test.dart';

import 'rendering_tester.dart';

class TestLayout {
  TestLayout() {
    // viewport incoming constraints are tight 800x600
    // viewport is vertical by default
    root = new RenderViewport(
      child: new RenderCustomPaint(
        painter: new TestCallbackPainter(
          onPaint: () { painted = true; }
        ),
        child: child = new RenderConstrainedBox(
          additionalConstraints: new BoxConstraints.tightFor(height: 10.0, width: 10.0)
        )
      )
    );
  }
  RenderBox root;
  RenderBox child;
  bool painted = false;
}

void main() {
  final ViewConfiguration testConfiguration = new ViewConfiguration(
    size: const Size(800.0, 600.0),
    devicePixelRatio: 1.0
  );

  test('onscreen layout does not affect offscreen', () {
    TestLayout onscreen = new TestLayout();
    TestLayout offscreen = new TestLayout();
    expect(onscreen.child.hasSize, isFalse);
    expect(onscreen.painted, isFalse);
    expect(offscreen.child.hasSize, isFalse);
    expect(offscreen.painted, isFalse);
    // Attach the offscreen to a custom render view and owner
    RenderView renderView = new RenderView(configuration: testConfiguration);
    PipelineOwner pipelineOwner = new PipelineOwner();
    renderView.attach(pipelineOwner);
    renderView.child = offscreen.root;
    renderView.scheduleInitialFrame();
    // Lay out the onscreen in the default binding
    layout(onscreen.root, phase: EnginePhase.paint);
    expect(onscreen.child.hasSize, isTrue);
    expect(onscreen.painted, isTrue);
    expect(onscreen.child.size, equals(const Size(800.0, 10.0)));
    // Make sure the offscreen didn't get laid out
    expect(offscreen.child.hasSize, isFalse);
    expect(offscreen.painted, isFalse);
    // Now lay out the offscreen
    pipelineOwner.flushLayout();
    expect(offscreen.child.hasSize, isTrue);
    expect(offscreen.painted, isFalse);
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();
    expect(offscreen.painted, isTrue);
  });
  test('offscreen layout does not affect onscreen', () {
    TestLayout onscreen = new TestLayout();
    TestLayout offscreen = new TestLayout();
    expect(onscreen.child.hasSize, isFalse);
    expect(onscreen.painted, isFalse);
    expect(offscreen.child.hasSize, isFalse);
    expect(offscreen.painted, isFalse);
    // Attach the offscreen to a custom render view and owner
    RenderView renderView = new RenderView(configuration: testConfiguration);
    PipelineOwner pipelineOwner = new PipelineOwner();
    renderView.attach(pipelineOwner);
    renderView.child = offscreen.root;
    renderView.scheduleInitialFrame();
    // Lay out the offscreen
    pipelineOwner.flushLayout();
    expect(offscreen.child.hasSize, isTrue);
    expect(offscreen.painted, isFalse);
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();
    expect(offscreen.painted, isTrue);
    // Make sure the onscreen didn't get laid out
    expect(onscreen.child.hasSize, isFalse);
    expect(onscreen.painted, isFalse);
    // Now lay out the onscreen in the default binding
    layout(onscreen.root, phase: EnginePhase.paint);
    expect(onscreen.child.hasSize, isTrue);
    expect(onscreen.painted, isTrue);
    expect(onscreen.child.size, equals(const Size(800.0, 10.0)));
  });
}
