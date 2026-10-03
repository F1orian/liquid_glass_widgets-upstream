# Native context-menu submenu demo

A minimal document screen for comparing `GlassMenu` layered submenus with a native iOS context menu. It uses this repository's `GlassMenu` directly. The demo draws only the document preview and stage; the package draws the menu, cards, rows, dimming, and transitions.

## Run

```sh
flutter pub get
flutter run -d chrome
```

For a phone on the same network, build the web app and serve `build/web` on a LAN address:

```sh
flutter build web --release
python3 -m http.server 8449 --bind <LAN-IP> --directory build/web
```

The web build is a visual approximation. It does not establish native iOS material, haptics, accessibility, or gesture parity. Native installation needs Xcode signing on macOS.

## Interaction

- Long-press, tap, or right-click the document to open the menu.
- Drag after a long press to glide over rows.
- Choose *Share*, *Move To*, or *Tag* to open a card. Choose its bold header or the dimmed parent to close it.
- Choose *Move To → Projects* to test nesting.
- Actions only close the menu; they do not share, move, tag, or delete anything.

URL parameters:

| Parameter | Effect |
| --- | --- |
| `placement=top` | Default document position used for reference captures |
| `placement=edge` | Places the document near the bottom; overhanging cards move the document and menu together |
| `placement=above` | Places the menu above the document; cards must not cover it |
| `open=1` | Opens the menu after the first frame |
| `capture=1` | Hides the instructions and controls |

## Captures

`screenshots/` contains Chromium web captures at 393 × 852 logical pixels: `root.png`, `share.png`, `move-to.png`, `tag.png`, `edge-root.png`, and `edge-tag.png`. Native references and the native transition recording are in Forage's `design/native-ios/context-menu-submenus/` directory.

`comparison/` places native iOS captures next to the demo at the same scale (iOS, GlassMenu, 50% overlay) for root, Share, Move To and Tag, plus opening and closing frame strips. The transition strips are not time-aligned.

The submenu card uses the same glass settings as the root menu. Its brighter appearance over the parent comes from compositing; there is no separate submenu tint.

## Checks

```sh
flutter analyze
flutter test
flutter build web --release
```
