import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(const NativeMenuDemo());
}

/// A service-free reproduction of the document and menu in the native captures.
class NativeMenuDemo extends StatelessWidget {
  const NativeMenuDemo({super.key});

  @override
  Widget build(BuildContext context) => LiquidGlassWidgets.wrap(
        theme: GlassThemeData.simple(quality: GlassQuality.minimal),
        child: const CupertinoApp(
          debugShowCheckedModeBanner: false,
          title: 'Native context-menu comparison',
          theme: CupertinoThemeData(brightness: Brightness.light),
          home: _DocumentScreen(),
        ),
      );
}

enum _Placement { top, edge, above }

class _DocumentScreen extends StatefulWidget {
  const _DocumentScreen();

  @override
  State<_DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<_DocumentScreen>
    with SingleTickerProviderStateMixin {
  // Reference scale: the 416px menu is 260pt and the 70px row pitch is ~44pt.
  static const _menuWidth = 260.0;
  static const _documentHeight = 92.0;
  static const _gap = 17.0;
  static const _margin = 24.0;
  static const _rootHeight = 326.0; // six rows + two dividers + normal padding
  static const _ink = Color(0xFF090909);
  static const _rowStyle = TextStyle(fontSize: 18, color: _ink);

  final _menu = GlassMenuController();
  late final AnimationController _motion;
  Tween<double> _translation = Tween(begin: 0, end: 0);
  double _shift = 0;
  bool _open = false;
  String? _lastAction;
  late _Placement _placement;
  late final bool _capture;
  Size _viewport = Size.zero;
  double _safeTop = 0;
  double _safeBottom = 0;

  @override
  void initState() {
    super.initState();
    final query = Uri.base.queryParameters;
    _placement = _Placement.values.firstWhere(
      (value) => value.name == query['placement'],
      orElse: () => _Placement.top,
    );
    _capture = query['capture'] == '1';
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(_applyTranslation);
    if (query['open'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMenu();
      });
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  bool get _above => _placement == _Placement.above;
  double get _top => switch (_placement) {
        _Placement.top => _safeTop + 40,
        _Placement.edge => math.max(
            _safeTop + _margin,
            _viewport.height -
                _safeBottom -
                _margin -
                _documentHeight -
                _gap -
                _rootHeight -
                8),
        _Placement.above => math.max(_safeTop + _margin,
            _viewport.height - _safeBottom - _margin - _documentHeight),
      };
  double get _anchor => _above ? _top - _gap : _top + _documentHeight + _gap;

  void _showMenu() {
    if (_open) return;
    setState(() => _open = true);
    _menu.open();
  }

  void _moveTo(double target) {
    if (target == _shift && !_motion.isAnimating) return;
    _translation = Tween(begin: _shift, end: target);
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
      _applyTranslation();
    } else {
      _motion.forward(from: 0);
    }
  }

  void _applyTranslation() {
    if (!mounted) return;
    final shift =
        _translation.transform(Curves.easeOutCubic.transform(_motion.value));
    setState(() => _shift = shift);
    // The preview and the REAL package menu follow exactly the same offset.
    // No menu bodies, submenu surfaces, or menu hit zones are drawn here.
    _menu.setFollowOffset(Offset(0, shift));
  }

  void _levelChanged(int depth, double height) {
    final shift = _above
        ? math.max(0.0, _safeTop + _margin - (_anchor - height))
        : math.min(
            0.0, _viewport.height - _safeBottom - _margin - (_anchor + height));
    _moveTo(shift);
  }

  void _close() {
    if (!mounted) return;
    setState(() => _open = false);
    _moveTo(0);
  }

  GlassMenuItem _item(String title, IconData icon,
          {List<Widget>? children, bool destructive = false}) =>
      GlassMenuItem(
        title: title,
        icon: Icon(icon),
        iconSize: 20,
        iconColor: destructive ? CupertinoColors.systemRed : _ink,
        titleStyle: _rowStyle.copyWith(
            color: destructive ? CupertinoColors.systemRed : _ink),
        isDestructive: destructive,
        enablePressScale: false,
        submenu: children,
        onTap: () => setState(
            () => _lastAction = '$title — demo only; nothing was changed.'),
      );

  late final List<Widget> _items = [
    _item('Open', CupertinoIcons.arrow_up_right_square),
    _item('Favorite', CupertinoIcons.star),
    const GlassMenuDivider(),
    _item('Share', CupertinoIcons.share, children: [
      _item('Messages', CupertinoIcons.chat_bubble),
      _item('Mail', CupertinoIcons.envelope),
      _item('Copy Link', CupertinoIcons.link),
    ]),
    _item('Move To', CupertinoIcons.folder, children: [
      _item('Inbox', CupertinoIcons.tray),
      _item('Archive', CupertinoIcons.archivebox),
      _item('Projects', CupertinoIcons.folder, children: [
        _item('Personal', CupertinoIcons.person),
        _item('Work', CupertinoIcons.briefcase),
      ]),
    ]),
    _item('Tag', CupertinoIcons.tag, children: [
      // The supplied native capture shows black dots, not colored swatches.
      for (final name in ['Red', 'Green', 'Blue'])
        _item(name, CupertinoIcons.circle_fill),
    ]),
    const GlassMenuDivider(),
    _item('Delete', CupertinoIcons.delete, destructive: true),
  ];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    _viewport = media.size;
    _safeTop = media.padding.top;
    _safeBottom = media.padding.bottom;
    final documentWidth = math.min(332.0, _viewport.width - 2 * _margin);
    return GlassScaffold(
      edgeToEdge: true,
      edgeFade: false,
      background: const ColoredBox(color: Color(0xFFCCCCCC)),
      body: Stack(children: [
        Positioned(
          left: (_viewport.width - documentWidth) / 2,
          top: _top + _shift,
          width: documentWidth,
          height: _documentHeight,
          child: GestureDetector(
            onTap: _showMenu,
            onSecondaryTap: _showMenu,
            onLongPressStart: (_) => _showMenu(),
            onLongPressMoveUpdate: (details) =>
                _menu.glideTo(details.globalPosition),
            onLongPressEnd: (_) => _menu.endGlide(),
            child: const _DocumentPreview(),
          ),
        ),
        Positioned(
          // A 2pt trigger centered on the document's axis; the relevant menu
          // edge is exactly one gap away. The trigger itself stays invisible.
          left: _viewport.width / 2 - 1,
          top: _above ? _anchor - 2 : _anchor,
          child: GlassMenu(
            controller: _menu,
            trigger: const SizedBox(width: 2, height: 2),
            morphFromZero: true,
            menuWidth: math.min(_menuWidth, _viewport.width - 2 * _margin),
            menuAlignment: _above
                ? GlassMenuAlignment.bottomCenter
                : GlassMenuAlignment.topCenter,
            autoAdjustToScreen: false,
            maxStackHeight: math.max(
                1, _viewport.height - _safeTop - _safeBottom - 2 * _margin),
            onLevelChanged: _levelChanged,
            onClose: _close,
            quality: GlassQuality.minimal,
            // Identical translucent material on root and child: over #ccc it
            // reads ~236 gray, and over the parent ~248, without a second veil.
            // This is a visual calibration, not Apple's native material.
            settings: const LiquidGlassSettings(
              glassColor: Color(0xA0FFFFFF),
              blur: 12,
              saturation: 1,
              thickness: 0,
              lightIntensity: 0,
              shadow: [
                BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 24,
                    offset: Offset(0, 10))
              ],
            ),
            stretch: 0,
            interactionScale: 1,
            enableInteractionGlow: false,
            items: _items,
          ),
        ),
        if (!_open && !_capture)
          Positioned(
            left: 24,
            right: 24,
            top: _above ? _safeTop + 24 : null,
            bottom: _above ? null : _safeBottom + 24,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                  _lastAction ??
                      'Long-press the document, then choose a submenu.',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF555555))),
              const SizedBox(height: 16),
              GlassSegmentedControl(
                selectedIndex: _placement.index,
                segments: const [
                  GlassSegment(label: 'Reference'),
                  GlassSegment(label: 'Near edge'),
                  GlassSegment(label: 'Above tile'),
                ],
                quality: GlassQuality.minimal,
                onSegmentSelected: (index) =>
                    setState(() => _placement = _Placement.values[index]),
              ),
              const SizedBox(height: 12),
              const Text('Flutter reproduction · not a native iOS capture',
                  style: TextStyle(fontSize: 11, color: Color(0xFF555555))),
            ]),
          ),
      ]),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview();

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('document'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(19),
          boxShadow: const [
            BoxShadow(
                color: Color(0x26000000), blurRadius: 28, offset: Offset(0, 8))
          ],
        ),
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00B5F5), Color(0xFF008AFF)]),
            ),
            child: const Icon(CupertinoIcons.doc_text_fill,
                color: CupertinoColors.white, size: 28),
          ),
          const SizedBox(width: 17),
          const Expanded(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quarterly Report.pdf',
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF090909))),
              SizedBox(height: 4),
              Text('2.4 MB · Edited yesterday',
                  maxLines: 1,
                  style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93))),
            ],
          )),
        ]),
      );
}
