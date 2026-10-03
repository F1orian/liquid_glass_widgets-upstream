import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:native_context_menu_demo/main.dart';

final document = find.byKey(const ValueKey('document'));
Finder surface(String title) => find
    .ancestor(of: find.text(title).first, matching: find.byType(GlassContainer))
    .first;
Rect rect(WidgetTester tester, Finder finder) =>
    Rect.fromPoints(tester.getTopLeft(finder), tester.getBottomRight(finder));

Future<void> launch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const NativeMenuDemo());
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester) async {
  await tester.longPress(document);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('native document and root geometry use the real GlassMenu',
      (tester) async {
    await launch(tester);
    expect(find.text('Quarterly Report.pdf'), findsOneWidget);
    expect(find.text('2.4 MB · Edited yesterday'), findsOneWidget);
    await open(tester);
    final menu = rect(tester, surface('Open'));
    expect(menu.width, closeTo(260, .01));
    expect(menu.height, closeTo(326, .01));
    expect(menu.top - rect(tester, document).bottom, closeTo(17, .05));
    expect(menu.center.dx, closeTo(rect(tester, document).center.dx, .05));
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Share matches the source row, recession and full card width',
      (tester) async {
    await launch(tester);
    await open(tester);
    final tile = rect(tester, document);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    final parent = rect(tester, surface('Open'));
    final card = rect(tester, surface('Messages'));
    expect(parent.width, closeTo(260 * .971, .05));
    expect(card.width, closeTo(260, .05));
    expect(card.center.dx, closeTo(parent.center.dx, .05));
    expect(tester.getCenter(find.text('Share').last).dy,
        closeTo(tester.getCenter(find.text('Share').first).dy, 2));
    expect(rect(tester, document), tile);
    expect(find.text('Back'), findsNothing);
    await tester.tap(find.text('Share').last);
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsNothing);
    expect(rect(tester, document), tile);
  });

  testWidgets(
      'edge overhang pushes the preview and menu together, then restores',
      (tester) async {
    await launch(tester);
    await tester.tap(find.text('Near edge'));
    await tester.pumpAndSettle();
    await open(tester);
    final tile = rect(tester, document);
    final root = rect(tester, surface('Open'));
    await tester.tap(find.text('Tag'));
    await tester.pumpAndSettle();
    final pushed = rect(tester, document);
    final parent = rect(tester, surface('Open'));
    final card = rect(tester, surface('Red'));
    expect(pushed.top, lessThan(tile.top - 20));
    expect(parent.top - root.top, closeTo(pushed.top - tile.top, .05));
    expect(parent.top - pushed.bottom, closeTo(17, .05));
    expect(card.bottom, closeTo(852 - 24, .1));
    await tester.tap(find.text('Tag').last);
    await tester.pumpAndSettle();
    expect(rect(tester, document).top, closeTo(tile.top, .05));
  });

  testWidgets('Projects nests and a demo action has no external effects',
      (tester) async {
    await launch(tester);
    await open(tester);
    await tester.tap(find.text('Move To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    final controller =
        tester.widget<GlassMenu>(find.byType(GlassMenu)).controller!;
    expect(controller.submenuDepth, 2);
    await tester.tap(find.text('Projects').last);
    await tester.pumpAndSettle();
    expect(controller.submenuDepth, 1);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(
        find.text('Archive — demo only; nothing was changed.'), findsOneWidget);
    expect(find.text('Quarterly Report.pdf'), findsOneWidget);
  });

  testWidgets('above-tile card never covers the document', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Above tile'));
    await tester.pumpAndSettle();
    await open(tester);
    await tester.tap(find.text('Move To'));
    await tester.pumpAndSettle();
    expect(rect(tester, surface('Inbox')).bottom,
        lessThanOrEqualTo(rect(tester, document).top - 17 + .05));
  });
}
