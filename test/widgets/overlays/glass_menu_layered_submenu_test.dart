import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// Public widget geometry, normalized to a 200pt root menu. Native reference:
// Forage #447: 416px root/card width, 404px receded parent, same centre,
// source row aligned to the bold card header, parent rows at 50% opacity.
Finder surfaceFor(Finder row) =>
    find.ancestor(of: row, matching: find.byType(GlassContainer)).first;
Rect paintedRect(WidgetTester tester, Finder finder) =>
    Rect.fromPoints(tester.getTopLeft(finder), tester.getBottomRight(finder));
Finder header(int depth) => find.byKey(ValueKey('glass-menu-header-$depth'));

Widget host(
  GlassMenuController controller, {
  GlassMenuAlignment alignment = GlassMenuAlignment.topLeft,
  void Function(int, double)? onLevelChanged,
  List<Widget>? items,
  bool reduceMotion = false,
}) =>
    MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
          body: Stack(children: [
        Positioned(
          left: 300,
          top: alignment == GlassMenuAlignment.topLeft ? 60 : 480,
          child: GlassMenu(
            controller: controller,
            menuAlignment: alignment,
            quality: GlassQuality.minimal,
            stretch: 0,
            interactionScale: 1,
            onLevelChanged: onLevelChanged,
            trigger: const SizedBox(width: 8, height: 8),
            items: items ??
                [
                  GlassMenuItem(title: 'Open', onTap: () {}),
                  GlassMenuItem(title: 'Favorite', onTap: () {}),
                  const GlassMenuDivider(),
                  GlassMenuItem(
                      title: 'Share',
                      icon: const Icon(CupertinoIcons.share),
                      onTap: () {},
                      submenu: [
                        GlassMenuItem(title: 'Messages', onTap: () {}),
                        GlassMenuItem(title: 'Mail', onTap: () {}),
                        GlassMenuItem(title: 'Copy Link', onTap: () {}),
                      ]),
                  GlassMenuItem(title: 'Move To', onTap: () {}, submenu: [
                    GlassMenuItem(title: 'Inbox', onTap: () {}),
                    GlassMenuItem(title: 'Archive', onTap: () {}),
                    GlassMenuItem(title: 'Projects', onTap: () {}, submenu: [
                      GlassMenuItem(title: 'Work', onTap: () {}),
                    ]),
                  ]),
                  GlassMenuItem(title: 'Tag', onTap: () {}),
                  const GlassMenuDivider(),
                  GlassMenuItem(title: 'Delete', onTap: () {}),
                ],
          ),
        )
      ])),
    ));

Future<void> open(WidgetTester tester, GlassMenuController c,
    {GlassMenuAlignment alignment = GlassMenuAlignment.topLeft,
    void Function(int, double)? onLevelChanged}) async {
  await tester.pumpWidget(
      host(c, alignment: alignment, onLevelChanged: onLevelChanged));
  c.open();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'a contained card reports the receded parent extent, not its old height',
      (tester) async {
    final c = GlassMenuController();
    final heights = <double>[];
    await tester
        .pumpWidget(host(c, onLevelChanged: (_, h) => heights.add(h), items: [
      GlassMenuItem(
          title: 'More',
          onTap: () {},
          submenu: [GlassMenuItem(title: 'Child', onTap: () {})]),
      for (var i = 0; i < 5; i++) GlassMenuItem(title: 'Row $i', onTap: () {}),
    ]));
    c.open();
    await tester.pumpAndSettle();
    final rootHeight = heights.single;
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(heights.last, closeTo(rootHeight * .971, .05));
    await tester.tap(header(1));
    await tester.pumpAndSettle();
    expect(heights.last, rootHeight);
  });

  testWidgets('glide reaches the overhang and can collapse via exposed parent',
      (tester) async {
    final c = GlassMenuController();
    await open(tester, c);
    c.glideTo(tester.getCenter(find.text('Move To')));
    expect(c.endGlide(), isTrue);
    await tester.pumpAndSettle();
    c.glideTo(tester.getCenter(find.text('Open')));
    expect(c.endGlide(), isTrue);
    await tester.pumpAndSettle();
    expect(c.submenuDepth, 0);
    await tester.tap(find.text('Move To'));
    await tester.pumpAndSettle();
    c.glideTo(tester.getCenter(find.text('Archive')));
    expect(c.endGlide(), isTrue);
    await tester.pumpAndSettle();
    expect(c.isOpen, isFalse);
  });

  testWidgets('Reduce Motion opens and collapses without intermediate geometry',
      (tester) async {
    final c = GlassMenuController();
    await tester.pumpWidget(host(c, reduceMotion: true));
    c.open();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pump();
    expect(c.submenuDepth, 1);
    expect(
        paintedRect(tester, surfaceFor(header(1))).height, closeTo(220, .05));
    await tester.tap(header(1));
    await tester.pump();
    expect(c.submenuDepth, 0);
  });

  testWidgets('native Share gate: full-width card overlays a receded parent',
      (tester) async {
    final c = GlassMenuController();
    await open(tester, c);
    final root = paintedRect(tester, surfaceFor(find.text('Open')));
    expect(root.width, closeTo(200, .01));
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    final parent = paintedRect(tester, surfaceFor(find.text('Open')));
    final card = paintedRect(tester, surfaceFor(header(1)));
    expect(parent.width, closeTo(194.2, .05));
    expect(parent.top, closeTo(root.top, .05));
    expect(parent.center.dx, closeTo(root.center.dx, .05));
    expect(card.width, closeTo(200, .05));
    expect(card.center.dx, closeTo(root.center.dx, .05));
    final source = find.text('Share').first;
    expect(tester.getCenter(header(1)).dy,
        closeTo(tester.getCenter(source).dy, 2));
    expect(find.text('Back'), findsNothing);
    expect(tester.widget<GlassMenuItem>(header(1)).titleStyle?.fontWeight,
        FontWeight.w600);
    expect(
        find.descendant(
            of: header(1), matching: find.byIcon(CupertinoIcons.chevron_down)),
        findsOneWidget);
    expect(
        tester
            .widgetList<Opacity>(find.ancestor(
                of: find.text('Open'), matching: find.byType(Opacity)))
            .any((o) => o.opacity == .5),
        isTrue);
    await tester.tap(header(1));
    await tester.pumpAndSettle();
    expect(c.submenuDepth, 0);
    expect(paintedRect(tester, surfaceFor(find.text('Open'))), root);
  });

  testWidgets('extent includes overhanging card and returns to root on pop',
      (tester) async {
    final c = GlassMenuController();
    final heights = <double>[];
    await open(tester, c, onLevelChanged: (_, h) => heights.add(h));
    final root = paintedRect(tester, surfaceFor(find.text('Open')));
    await tester.tap(find.text('Move To'));
    await tester.pumpAndSettle();
    final card = paintedRect(tester, surfaceFor(header(1)));
    expect(card.bottom, greaterThan(root.bottom));
    expect(heights.last, closeTo(card.bottom - root.top, .05));
    // Touching the exposed parent collapses; it never runs the parent action.
    await tester.tapAt(tester.getCenter(find.text('Open')));
    await tester.pumpAndSettle();
    expect(c.isOpen, isTrue);
    expect(c.submenuDepth, 0);
    expect(heights.last, heights.first);
  });

  testWidgets('upward menu keeps card on the menu side of its anchor',
      (tester) async {
    final c = GlassMenuController();
    await open(tester, c, alignment: GlassMenuAlignment.bottomRight);
    final root = paintedRect(tester, surfaceFor(find.text('Open')));
    await tester.tap(find.text('Move To'));
    await tester.pumpAndSettle();
    final card = paintedRect(tester, surfaceFor(header(1)));
    expect(card.bottom, lessThanOrEqualTo(root.bottom + .05));
    await tester.tap(header(1));
    await tester.pumpAndSettle();
    expect(c.isOpen, isTrue);
  });

  testWidgets(
      'nested card pops one level; covered rows have no semantics actions',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final c = GlassMenuController();
    await open(tester, c);
    await tester.tap(find.text('Move To'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(c.submenuDepth, 2);
    expect(find.bySemanticsLabel('Open'), findsNothing);
    final node = tester.getSemantics(find.bySemanticsLabel('Projects').first);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(c.submenuDepth, 1);
    expect(find.text('Inbox'), findsOneWidget);
    await tester.tap(header(1));
    await tester.pumpAndSettle();
    expect(c.submenuDepth, 0);
    semantics.dispose();
  });
}
