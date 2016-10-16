// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the CHROMIUM_LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

List<int> items = <int>[0, 1, 2, 3, 4, 5];

Widget buildCard(BuildContext context, int index) {
  if (index >= items.length)
    return null;
  return new Container(
    key: new ValueKey<int>(items[index]),
    height: 100.0,
    child: new DefaultTextStyle(
      style: new TextStyle(fontSize: 2.0 + items.length.toDouble()),
      child: new Text('${items[index]}')
    )
  );
}

Widget buildFrame() {
  return new LazyBlock(
    delegate: new LazyBlockBuilder(builder: buildCard)
  );
}

void main() {
  testWidgets('LazyBlock is a build function (smoketest)', (WidgetTester tester) async {
    await tester.pumpWidget(buildFrame());
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    items.removeAt(2);
    await tester.pumpWidget(buildFrame());
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    expect(find.text('3'), findsOneWidget);
  });
}
