# Explore — the map tab

Explore shows the people the Radar tab would show you, on the ground they are
roughly on. It is a second way of *looking* at discovery, not a second
discovery system.

## Configuration

Nothing is required. The map works out of the box on
[OpenFreeMap](https://openfreemap.org), which serves OpenMapTiles-schema vector
tiles with no key and no account.

To move to another provider, set these in `.env` (see `.env.example`) and pass
it with `--dart-define-from-file=.env`:

| Key | Default | Notes |
|---|---|---|
| `MAP_TILES_URL` | `https://tiles.openfreemap.org/planet` | TileJSON URL. A literal `{key}` is replaced with `MAP_TILES_API_KEY`. |
| `MAP_GLYPHS_URL` | `https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf` | Keep `{fontstack}` and `{range}` — MapLibre fills those in. |
| `MAP_TILES_API_KEY` | *(empty)* | Only for providers that need one. |

**Never commit a real token.** Pass it at build time and leave the key out of
`.env` itself:

```bash
flutter build apk --dart-define-from-file=.env --dart-define=MAP_TILES_API_KEY=xxx
```

Restrict the key at the provider (referer / bundle-id allowlist, usage cap):
anything shipped in a client is readable by anyone who installs it.

Known-good alternatives, both on the same schema:

```
MAP_TILES_URL=https://api.maptiler.com/tiles/v3/tiles.json?key={key}
MAP_TILES_URL=https://tiles.stadiamaps.com/data/openmaptiles.json?api_key={key}
```

## How the data gets there

```
MongoDB $geoNear  →  DiscoveryService.getExplore  →  GET /discovery/explore
                  →  DiscoveryRepository.explore  →  exploreProvider  →  ExploreMap
```

`getExplore` reuses `buildQuery` — the *same* method `getNearby` uses — so
radius, show-me, age, intent, verified, recently-active, tags, account status
and the blocklist are all decided once, on the server. The only thing the map
endpoint adds is `mapPosition`.

There is deliberately no client-side filtering of the result anywhere in the
Flutter code. If the map ever hid somebody the API returned, that would be a
second copy of the discovery rules, and it would diverge.

**Blocking** is enforced by the same `excludeUserIds` the grid uses, and
`ChatActions.blockUser` refreshes `exploreProvider` so a block takes markers,
cluster counts and any open preview off the map immediately.

### Positions are not locations

`mapPosition` is the stored point pushed 350–900 m along a per-user-stable
bearing, then snapped to a ~500 m grid
(`DiscoveryService.generalizeMapPosition`). Stable, so a marker does not jitter
between refreshes; coarse, so a marker is not an address. The client never
receives a real coordinate for anybody else.

Because positions are snapped, exact collisions are normal in a dense city, and
a marker perfectly hidden under another marker is a person who cannot be
tapped. `spreadColocated` (`presentation/explore/marker_layout.dart`) pushes
duplicates onto a ring inside their own cell — deterministically, from the
sorted ids, so the arrangement survives a refresh.

## Rendering

Everything positional is rendered by MapLibre. There are no Flutter widgets
over the map except the chrome, because projecting N markers per frame of a pan
is a platform round-trip per marker per frame, and markers positioned that way
visibly lag the ground under rotation and pitch.

| Thing | How |
|---|---|
| Terrain, roads, 3D buildings | `assets/map/explore_style.json`, a real style document |
| People | GeoJSON source → symbol layer, icons rasterised by `ExploreMarkerImages` |
| Clusters | Same source, `cluster: true` → circle + count layers |
| You | Second GeoJSON source → pulse, core, `YOU` label |

A marker is a bitmap, so it cannot animate its own contents. Entrance,
selection and the "you" pulse are animated on the **layer** instead — three
interpolations total, throttled to ~22 fps and ~11 fps, regardless of how many
people are on screen. There is no per-person animation controller.

`setLayerProperties` sends its property map *without* skipping nulls, so
anything omitted is reset to default. Every property set therefore goes through
one builder (`_personProperties`, `_mePulseProperties`) used by both layer
creation and the animation ticks.

### Editing the style

`explore_style.json` reads OpenMapTiles source layers by name. `flutter analyze`
cannot see inside it, so `test/explore_map_style_test.dart` is the compiler it
doesn't have: it checks the source layers are real, the placeholders are
present, the terrain colours still match `AppMapColors`, and that `building-3d`
is still a `fill-extrusion` driven by `render_height`. Run it after any edit.

Terrain colours are defined **twice** — in `AppMapColors` and in the JSON — and
the test asserts they agree. Change both.

## Platforms

Android and iOS use maplibre-native, bundled by the plugin. Web uses
maplibre-gl-js, loaded by the script tags in `web/index.html`; keep that version
in step with `maplibre_gl_web`.

## Camera

The map **frames itself on the result set** (`frameFor` in
`marker_layout.dart`) whenever a new set of people arrives — first load, radius
change, filter change. It does not open at a fixed zoom.

That is not a nicety. The first version did open at a fixed zoom, which on a
phone-width viewport covers about ±3.4 km, while the radius filter goes up to
"10 km+". With a wide radius the request was correct, the header counted the
right people, and every one of them rendered off screen. An empty-looking map
gives the user no reason to think scrolling would help.

Framing computes centre and zoom directly rather than using
`CameraUpdate.newLatLngBounds`, because that helper resets tilt and bearing to
zero — it would flatten the 3D view every time the radius changed.

Centre-on-me deliberately preserves the current zoom: somebody who pulled back
to take in a 10 km radius pressed it to find themselves in that view, not to be
dropped back to street level.

## Web quirks

`maplibre_gl_web` does not implement everything the native platforms do, and it
fails in two different ways:

- **`queryCameraPosition()` throws `UnimplementedError`.** Use the controller's
  synchronous `cameraPosition` getter instead — it is kept current by the
  camera-move stream (`trackCameraPosition: true`) and needs no platform call.
- **`setLayerProperties` applies paint properties but silently drops layout
  ones** (it tries `setPaintProperty` first, and GL JS reports an unknown
  property through an error *event* rather than by throwing, so the
  `setLayoutProperty` fallback never runs). So `icon-opacity` animates on web
  and `icon-size` does not.

Because of the second point, **every layer is created in its fully visible
state** and the entrance animation is layered on top. A layer whose only route
to being visible is a stream of property pushes is a layer that renders nothing
at all on any platform where those pushes quietly do nothing.

The people layer also has a geometry-drawn ground dot beneath it, so a person
stays visible and tappable even if their face fails to rasterise or register.

## Known limitations

- **Individual markers carry no semantics.** They are GPU-rendered symbols, not
  widgets, so a screen reader sees the map as one labelled surface. The preview
  sheet that a tap opens is fully labelled.
- **The map is rebuilt on every tab switch**, because `HomeScreen._body()`
  switches widgets rather than keeping them alive. Style and tiles are cached,
  so this is a re-render rather than a re-download, but an `IndexedStack` would
  remove it — at the cost of keeping all five tabs alive for the whole session.
- **Opening Explore spends a `NEARBY_REVEAL`**, exactly as opening the Radar
  grid does, because it is the same gate on the same endpoint family. The
  paywall card offers the same two ways past it.
