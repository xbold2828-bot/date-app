# Explore — the map tab

Explore shows the people you are **vibing with** — conversations both sides have
spoken in — on the ground they are roughly on, with a message box under the map.

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

## Who is on the map

**Only the people you are vibing with.** Not discovery, not matches, not
everyone nearby.

```
conversations (state: VIBING)  →  MessagingService.mapPeople
                               →  GET /messaging/map
                               →  ChatRepository.mapPeople
                               →  exploreProvider  →  ExploreMap
```

VIBING means the recipient replied, so both people have opted into the
conversation. **NEW_ENERGY is deliberately excluded**: that state is one person
who reached out and has not been answered, and a location is not something to
hand an unanswered sender. The rule is enforced server-side, in the repository
query — not by filtering in the client.

Consequences worth stating, because they are why controls that used to be here
have gone:

- **No entitlement gate.** These are conversations the user already has.
  Charging a discovery reveal to look at them on a map would be charging twice.
- **No radius control.** Radius parameterises a proximity search. This is not
  one, and a thread outlives the proximity that started it.
- **No discovery filters.** Same reason: filters decide who a search for
  strangers returns, and there is no such search here.

Blocking is passed to the repository as `excludeUserIds`, read live, so a block
clears somebody off the map in both directions on the next load —
`ChatActions._refreshInbox` triggers that load, because anything changing which
conversations exist changes who belongs on the map.

`GET /discovery/explore` and `DiscoveryService.getExplore` were **removed**; the
Explore map no longer touches discovery at all.

## Radar and Explore are separate feeds

They answer different questions from different endpoints, and the only thing
they share is the user's own location:

| | Radar | Explore |
|---|---|---|
| Shows | every eligible stranger nearby | people you are vibing with |
| Endpoint | `GET /discovery/nearby` | `GET /messaging/map` |
| Provider | `nearbyProvider` | `exploreProvider` |
| Costs | one of **10 free reveals a day** | nothing |

**Nothing in Explore may refresh `nearbyProvider`.** That rule exists because
breaking it broke Radar: the location sync refreshed the discovery feed on
every re-anchor, so a few Explore visits drained the daily allowance, after
which `/discovery/nearby` answered 402 and Radar rendered the paywall with no
profiles on it at all. It looked exactly like "Explore has taken over Radar".

`HomeScreen.didChangeAppLifecycleState` refuses to refresh Radar on resume for
the same reason. Radar is a snapshot until pulled to refresh; nothing should
spend a user's daily quota on their behalf in the background.

The anchor therefore lives in `providers/location_provider.dart`, not in
`explore_provider.dart` — it belongs to the whole app, and keeping it inside
Explore is what let an Explore detail reach into Radar in the first place.

### The anchor

`me.location.point` is the **anchor**: the point the server measures everyone's
distance from, and the point the map draws "you are here" at. Those must be the
same number, and `MyLocationNotifier` is what keeps them that way — it takes a
device fix, rewrites the anchor when it has genuinely moved (>150 m, or the
stored point is over 30 minutes old), and returns the anchor.

This was broken on the first cut. `PATCH /location` was called from exactly one
place — onboarding step 5 — so the anchor froze at signup while the map marker
tracked the live device. Move afterwards and the map drew you on one street
while presenting people who had been selected, ranked and distance-banded from
another. Testing several accounts on one machine made it look stranger still:
every account got the identical device fix, so "you" appeared in the same spot
for all of them, which reads as a hardcoded location.

`MeView.location` therefore now carries `latitude`/`longitude`. That is the one
view that goes only to the person the data is about; **no other user's view has
ever carried a coordinate, and none may**.

The automatic re-anchor **refuses a fix reporting worse than 1 km of accuracy**
when an anchor already exists. A browser with no GPS answers from the IP
address, which can be another suburb or another city; moving a real anchor there
silently relocates the account and Radar then searches somewhere the user has
never been — which is how several test accounts on one laptop stopped seeing
each other. A coarse fix is still better than no anchor, so the guard only
applies to accounts that already have one.

Because that guard also blocks *correcting* an anchor that is already wrong,
`LiveLocationLine` on the You tab offers **"Move my radar here"** whenever the
live fix is more than 150 m from the stored anchor. Explicit, one tap, and the
only route back for an anchor that has been stranded.

`PATCH /location` also only writes `preferredBand` and `city` when the caller
actually sends them. It is no longer onboarding-only, and unconditionally
`$set`ing an absent band would have cleared the user's chosen radius on every
re-anchor, silently widening their discovery to the 50 km fallback.

### Positions are not locations

`mapPosition` is the stored point pushed 350–900 m along a per-user-stable
bearing, then snapped to a ~500 m grid
(`generalizeMapPosition` in `common/utils/geo.util.ts`). Stable, so a marker does not jitter
between refreshes; coarse, so a marker is not an address. The client never
receives a real coordinate for anybody else.

**This is why a friend sitting next to you does not appear next to you.** Worst
case the two displacements compound to roughly 1.2 km, so during testing a room
full of accounts renders as a loose ring about a kilometre away. That is the
feature working. The knob, if the policy is ever revisited, is
`generalizeMapPosition` — the `0.35 + … * 0.55` km offset and the `0.005°`
snap — and nothing else needs to change.

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

## The screen

```
┌──────────────────────────────────┐
│ ✦ Explore                   🔍   │  header — count, search
│ 24 people around you             │
├──────────────────────────────────┤
│ (All) (Emma) (Jason) (Olivia) …  │  people strip — horizontal, tap to pick
├──────────────────────────────────┤
│                            ⌄ 3D  │
│              MAP           + / − │  map — floating controls
│                            ◎     │
├──────────────────────────────────┤
│ (avatar) Message Emma…      ➤    │  composer — always visible
└──────────────────────────────────┘
```

Header, strip and composer are laid out in a `Column` with the map in the
middle. Only the transient things — map controls, notices, the preview — float
over the map. Stacking all of it produced a composer that a notice card could
sit on top of.

### Picking somebody

Selection arrives from three places — a marker, the strip, the grid — and they
all write `exploreSelectionProvider`. `ExploreMap._applySelection` is the single
place that reacts, so all three land the camera identically.

Picking somebody **empties the map of everyone else**: the people layer and all
three cluster layers are filtered to nothing and only the selected marker
survives. Highlighting them and leaving the crowd up makes "who am I looking
at" a question the user has to keep re-answering, and it makes the composer
ambiguous. With one person on the map, the message obviously goes to them.

"All" in the strip **opens the grid**. The grid carries its own "All" tile,
which is what puts everybody back on the map — so the grid is never a one-way
door into a focused map, and the two gestures sit one tap apart. When somebody
is selected they take the strip's first tile and "All" slides to second, so the
current subject is always under the thumb and the way onwards is next to it.

There is no profile preview. Tapping somebody focuses the map on them and points
the composer at them; that is the whole interaction. Like and View Profile live
on the Radar tab, where meeting somebody new is the point.

### Picking somebody: what the map does

`peopleLayerFilters` (in `marker_layout.dart`) decides which of the three
person layers draws whom. It is a pure function because getting it wrong is
invisible in review and glaring to a user:

|                   | nobody picked | picked, raster ready  | picked, not ready |
|---|---|---|---|
| base people layer | everyone      | nobody                | just them, plain marker |
| selected layer    | nobody        | just them, big marker | nobody |
| clusters          | shown         | hidden                | hidden |

The third column is the fix for a shipped bug. The selected marker is a larger
raster built on demand, so it never exists on a first pick — and the map used
to hide the crowd immediately while the selected layer still had nobody to
draw. Tapping a face emptied the map, which reads as the tap having broken the
screen rather than having selected anyone. If the raster then failed, the map
stayed empty and the failure reached the console as an unhandled async error.
Now the base layer covers until the raster lands, so **exactly one layer always
draws the person in focus**, and a raster failure costs the highlight rather
than the person.

Taps resolve through `queryRenderedFeatures` first, then fall back to
`personNearTap`, which measures the tap against the marker coordinates already
held in Dart. The rendered query is the precise tool and the fragile one: every
layer id in the request must exist, and maplibre-gl-js answers a request naming
an unknown layer with a console error and an empty list — indistinguishable
from a tap on the road. The fallback declines while the map is clustered, where
the nearest person may be inside a cluster the user was aiming at.

While somebody is in focus, `ExploreFocusPill` names them and offers one tap
back to everyone. Without it the only route back is through the grid.

### The grid

`ExplorePeopleGrid` is the "All people (52)" view: everyone at once with a name
search, presented as a sheet rather than a route — pushing a page would unmount the map, and rebuilding
a vector map to show a list of faces is an absurd price. Reached from the header
search icon, or the "See all" tile that appears once the strip passes
`ExplorePeopleStrip.gridThreshold`.

### The composer

`ExploreComposer` sends through `ChatActions.open` — the same call the full
profile sheet makes. Openers from the map are ordinary first messages: same
conversation, same New-Energy gating, same 402 paywall. There is no second
messaging path. With nobody selected there is no addressee, so it goes quiet and
says what to do rather than failing on send. Switching recipient clears the
field — delivering a half-typed message to the wrong person is unrecoverable.

**Not built:** the reference design's notification bell. No notification centre
exists in this app to open, and inventing one is a feature, not a layout change.

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
