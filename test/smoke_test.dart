// Smoke test: ensure the app launches without throwing, key widgets render.
// Run with: flutter test

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_epsilon/theme.dart';
import 'package:v_epsilon/widgets/common.dart';

void main() {
  testWidgets('VEAvatar renders with gradient fallback when no URL', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: VETheme.I.themeData,
      home: const Scaffold(
        body: Center(child: VEAvatar(seed: 'Alice', size: 48)),
      ),
    ));
    expect(find.text('A'), findsOneWidget); // First letter fallback
  });

  testWidgets('VEBadge renders known badge types', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Row(children: [
          VEBadge(type: 'human'),
          VEBadge(type: 'verified'),
          VEBadge(type: 'creator'),
          VEBadge(type: 'kernel'),
          VEBadge(type: 'top_tier'),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('VEBadge tolerates unknown types', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VEBadge(type: 'unknown_type_xyz')),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('VEChipRow notifies on tap', (tester) async {
    String selected = 'a';
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (ctx, setState) => Scaffold(
          body: VEChipRow(
            labels: const ['A', 'B', 'C'],
            active: selected,
            onChanged: (v) => setState(() => selected = v),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(selected, 'b');
  });
}
