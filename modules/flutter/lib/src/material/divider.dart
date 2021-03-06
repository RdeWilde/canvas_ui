// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the CHROMIUM_LICENSE file.

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// A material design divider.
///
/// A one logical pixel thick horizontal line, with padding on either
/// side. The box's total height is controlled by [height].
///
/// Dividers can be used in lists and [Drawer]s to separate content vertically.
/// To create a one-pixel divider between items in a list, consider using
/// [ListItem.divideItems], which is optimized for this case.
///
/// See also:
///
///  * [ListItem.divideItems]
///  * [PopupMenuDivider]
///  * <https://www.google.com/design/spec/components/dividers.html>
class Divider extends StatelessWidget {
  /// Creates a material design divider.
  ///
  /// The height must be at least 1.0 logical pixels.
  Divider({
    Key key,
    this.height: 16.0,
    this.indent: 0.0,
    this.color
  }) : super(key: key) {
    assert(height >= 1.0);
  }

  /// The divider's vertical extent.
  ///
  /// The divider itself is always drawn as one logical pixel thick horizontal
  /// line that is centered within the height specified by this value.
  final double height;

  /// The amount of empty space to the left of the divider.
  final double indent;

  /// The color to use when painting the line.
  ///
  /// Defaults to the current theme's divider color, given by
  /// [ThemeData.dividerColor].
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double bottom = (height ~/ 2.0).toDouble();
    return new Container(
      height: 0.0,
      margin: new EdgeInsets.only(
        top: height - bottom - 1.0,
        left: indent,
        bottom: bottom
      ),
      decoration: new BoxDecoration(
        border: new Border(
          bottom: new BorderSide(color: color ?? Theme.of(context).dividerColor)
        )
      )
    );
  }
}
