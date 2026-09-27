# Dialog and Callout Standardisation Report

Date: 2026-08-30

## Scope

This review covers two areas:

1. Dialogs and overlay-style modals used throughout the app.
2. Hill cards and start point cards shown when map annotations are tapped or selected.

I reviewed the overlay and map presentation code in:

- [`GenericOverlayViewControllers.swift`](./MapHills/Core/Overlays/GenericOverlayViewControllers.swift)
- [`MenuOverlayViewController.swift`](./MapHills/Core/Overlays/MenuOverlayViewController.swift)
- [`AboutOverlayViewController.swift`](./MapHills/Core/Overlays/AboutOverlayViewController.swift)
- [`RecordsOverlayViewController.swift`](./MapHills/Core/Overlays/RecordsOverlayViewController.swift)
- [`SettingsOverlayViewController.swift`](./MapHills/Core/Overlays/SettingsOverlayViewController.swift)
- [`WeatherOverlayViewController.swift`](./MapHills/Core/Overlays/WeatherOverlayViewController.swift)
- [`GPXOverlayViewController.swift`](./MapHills/Core/Overlays/GPXOverlayViewController.swift)
- [`CachingOverlayViewController.swift`](./MapHills/Core/Overlays/CachingOverlayViewController.swift)
- [`GoToHillOverlayViewController.swift`](./MapHills/Core/Overlays/GoToHillOverlayViewController.swift)
- [`WaypointsOverlayViewController.swift`](./MapHills/Core/Overlays/WaypointsOverlayViewController.swift)
- [`SavedGPXRecordingsOverlayViewController.swift`](./MapHills/Core/Overlays/SavedGPXRecordingsOverlayViewController.swift)
- [`AdvancedFilterOverlayViewController.swift`](./MapHills/Core/Overlays/AdvancedFilterOverlayViewController.swift)
- [`MapViewController+OverlayRouting.swift`](./MapHills/Core/Map/MapViewController+OverlayRouting.swift)
- [`MapViewController+StateAndNavigation.swift`](./MapHills/Core/Map/MapViewController+StateAndNavigation.swift)
- [`MapViewController+Actions.swift`](./MapHills/Core/Map/MapViewController+Actions.swift)
- [`MapViewController+Waypoints.swift`](./MapHills/Core/Map/MapViewController+Waypoints.swift)
- [`MapViewController+GPXFiles.swift`](./MapHills/Core/Map/MapViewController+GPXFiles.swift)
- [`MapViewController.swift`](./MapHills/Core/Map/MapViewController.swift)
- [`PeakCalloutsAndGPX.swift`](./MapHills/Core/Overlays/PeakCalloutsAndGPX.swift)
- [`CachedAreaCalloutView.swift`](./MapHills/Core/Overlays/CachedAreaCalloutView.swift)

I did not find any `UIAlertController` usage in the project tree. The dialog surface is custom UIKit overlay code.

## Issue 1: Dialog Inconsistency

### What Exists Today

The app uses a small set of reusable dialog primitives, then layers many feature-specific overlay controllers on top of them.

| Family | Current implementation | Current pattern | Notable inconsistencies |
|---|---|---|---|
| Confirmation dialogs | [`ConfirmationOverlayViewController`](./MapHills/Core/Overlays/GenericOverlayViewControllers.swift:39) | Centered card, dimmed backdrop, title + message + 2 buttons | Title/body/button typography is fixed, but copy, confirm colors, and action ordering vary by caller. |
| Option selection dialogs | [`SelectionOverlayViewController`](./MapHills/Core/Overlays/GenericOverlayViewControllers.swift:183) | Centered card, vertical list of option buttons, Done footer | Selected-state treatment is bespoke, and the action rows do not match the style used by `ActionOverlayViewController`. |
| Action menus / info dialogs | [`ActionOverlayViewController`](./MapHills/Core/Overlays/GenericOverlayViewControllers.swift:337) | Centered card, title + optional message + stacked actions | Used for everything from info messages to destructive confirmations, so the semantics of the same visual pattern vary a lot. |
| Text prompts | [`TextInputOverlayViewController`](./MapHills/Core/Overlays/GenericOverlayViewControllers.swift:493) | Centered card, title + optional message + text field + 2 buttons | Default placeholder, initial text, and confirm labels differ widely by feature. |
| Large menu / settings overlays | [`MenuOverlayViewController`](./MapHills/Core/Overlays/MenuOverlayViewController.swift:55), [`SettingsOverlayViewController`](./MapHills/Core/Overlays/SettingsOverlayViewController.swift:10), [`RecordsOverlayViewController`](./MapHills/Core/Overlays/RecordsOverlayViewController.swift:12), [`GPXOverlayViewController`](./MapHills/Core/Overlays/GPXOverlayViewController.swift:11), [`CachingOverlayViewController`](./MapHills/Core/Overlays/CachingOverlayViewController.swift:11), [`WaypointsOverlayViewController`](./MapHills/Core/Overlays/WaypointsOverlayViewController.swift:11), [`SavedGPXRecordingsOverlayViewController`](./MapHills/Core/Overlays/SavedGPXRecordingsOverlayViewController.swift:11), [`AdvancedFilterOverlayViewController`](./MapHills/Core/Overlays/AdvancedFilterOverlayViewController.swift:10), [`AboutOverlayViewController`](./MapHills/Core/Overlays/AboutOverlayViewController.swift:22), [`WeatherOverlayViewController`](./MapHills/Core/Overlays/WeatherOverlayViewController.swift:4), [`GoToHillOverlayViewController`](./MapHills/Core/Overlays/GoToHillOverlayViewController.swift:11) | Each owns its own title, section hierarchy, scroll behavior, and sizing rules | This is where the visual inconsistency is most visible. The overlays all share a card + dimming pattern, but they do not share enough layout tokens or hierarchy rules. |

### Observations By Family

#### 1. Confirmation / selection / action / text input overlays

The shared primitives in [`GenericOverlayViewControllers.swift`](./MapHills/Core/Overlays/GenericOverlayViewControllers.swift:39) are visually close, but not fully standardised:

- Titles are usually `17pt bold`, but the vertical rhythm differs because some controllers use 12pt spacing, some 16pt spacing, and some have a footer container.
- Button heights are standardized at 42pt, but button fill treatment varies by semantic role.
- The dimming alpha is usually `0.35`, but the card content margins and footer arrangements are not identical.
- Copy conventions vary:
  - Some dialogs use sentence-style titles.
  - Some use terse command titles such as `Done`.
  - Some use status-first titles like `Not Found`.
  - Some use feature-specific titles that mix verbs and nouns inconsistently, such as `Save/Share...`.
- The same `ActionOverlayViewController` is used for both benign information and destructive confirmations, which makes the visual language less precise than it could be.

Relevant call sites include:

- [`MapViewController+StateAndNavigation.swift`](./MapHills/Core/Map/MapViewController+StateAndNavigation.swift:232) for Go To, log/unlog, location access, GPX permissions, and offline cache deletes.
- [`MapViewController+Actions.swift`](./MapHills/Core/Map/MapViewController+Actions.swift:87) for map-layer selection and save prompts.
- [`MapViewController+Waypoints.swift`](./MapHills/Core/Map/MapViewController+Waypoints.swift:14) for waypoint actions and rename.
- [`MapViewController+GPXFiles.swift`](./MapHills/Core/Map/MapViewController+GPXFiles.swift:143) for GPX import and save prompts.
- [`SavedGPXRecordingsOverlayViewController.swift`](./MapHills/Core/Overlays/SavedGPXRecordingsOverlayViewController.swift:153) for file actions and delete confirmation.

#### 2. Large overlay screens

The larger feature overlays are individually well built, but they do not share a single presentation contract:

- [`MenuOverlayViewController.swift`](./MapHills/Core/Overlays/MenuOverlayViewController.swift:55) mixes a top title row, multiple scroll views, filter sections, and action buttons.
- [`RecordsOverlayViewController.swift`](./MapHills/Core/Overlays/RecordsOverlayViewController.swift:12) combines summary, search, table, and footer actions in one tall card.
- [`SettingsOverlayViewController.swift`](./MapHills/Core/Overlays/SettingsOverlayViewController.swift:10) uses many sectioned controls and different control types.
- [`GPXOverlayViewController.swift`](./MapHills/Core/Overlays/GPXOverlayViewController.swift:11) has a status panel, metrics grid, and multiple action groups.
- [`CachingOverlayViewController.swift`](./MapHills/Core/Overlays/CachingOverlayViewController.swift:11) has a fixed-width card and a table-backed list.
- [`AboutOverlayViewController.swift`](./MapHills/Core/Overlays/AboutOverlayViewController.swift:22) uses a taller card with collapsible sections.
- [`WeatherOverlayViewController.swift`](./MapHills/Core/Overlays/WeatherOverlayViewController.swift:4) is structurally different again because it has a loading state, a forecast grid, and attribution.
- [`GoToHillOverlayViewController.swift`](./MapHills/Core/Overlays/GoToHillOverlayViewController.swift:11) is the most visually distinct, with a dark live metric box and very large numeric typography.

The result is that the app feels internally consistent at the card level, but not at the dialog-system level.

### Standardisation Recommendations

#### A. Define a shared overlay chrome spec

Create one shared “dialog chrome” helper or style object that owns:

- card corner radius
- dimming alpha
- outer margins
- title font
- body font
- section header font
- button height
- default button corner radius
- standard spacing tokens
- standard safe-area inset policy

This would not force every overlay to look identical, but it would ensure that a confirmation prompt, an info prompt, and a large settings sheet all sit on the same visual baseline.

#### B. Split dialogs into four explicit categories

Use separate layout rules for:

1. Confirmation dialogs
2. Action menus
3. Input dialogs
4. Large content overlays

At the moment, `ActionOverlayViewController` is doing too much. A more precise classification would make the UI easier to reason about and would reduce copy and style drift.

#### C. Standardise title and body copy

Normalize dialog wording so the app uses one consistent tone:

- Prefer sentence case and short verb-led titles.
- Avoid mixed formatting such as `Save/Share...` unless there is a strong reason.
- Prefer explicit confirmation questions for destructive actions.
- Use the same naming pattern for `Cancel`, `Done`, `Save`, `Delete`, `Open`, and `Apply`.

Examples of wording that should be reviewed for consistency:

- `GoTo` versus `Go To`
- `Download Visible Area for Offline Use` versus `Save Visible Area for Offline Use`
- `Not Found`
- `GPX Import Failed`
- `Delete All Cached Areas?`

#### D. Make button semantics consistent

The current dialogs already use some semantic coloring, but the mapping is not fully standardised.

Recommended baseline:

- Primary affirmative action: filled blue button
- Cancel / dismiss: secondary neutral button
- Destructive action: filled red button
- Passive information dialogs: one neutral dismiss action

Also standardize action ordering:

- Cancel on the left, confirm on the right for two-button dialogs
- Destructive actions should be visually and positionally consistent across the app

#### E. Reduce nested scroll complexity

Several overlays contain nested scroll containers or scrollable subpanes. That makes the layout harder to predict and increases the chance that the user sees different scroll behavior between similar dialogs.

Recommended baseline:

- One primary scroll container per overlay
- No nested vertical scroll views unless there is a clear reason
- Tables and large lists should either fill their section or live inside the one primary scroll container

#### F. Harmonise typography tiers

There is a lot of font variety across the app, but the hierarchy should be more deliberate.

Recommended token set:

- Dialog title: `17-20pt semibold`
- Section title: `15-17pt semibold`
- Body copy: `13-14pt regular`
- Supporting note: `12-13pt regular` in secondary label color
- Action labels: `16pt semibold`

That would still allow some differentiation, but it would remove the current “every overlay chose its own scale” feeling.

#### G. Prioritise the shared primitives first

The fastest path to visible improvement is:

1. Standardise `ConfirmationOverlayViewController`, `SelectionOverlayViewController`, `ActionOverlayViewController`, and `TextInputOverlayViewController`.
2. Extract shared chrome tokens into a reusable helper.
3. Then align the feature overlays one by one.

That order gets the biggest consistency gain with the least behavior risk.

## Issue 2: Hill Card and Start Point Card Positioning

### What Exists Today

The hill and start point cards are custom MapLibre callout views, not generic modals.

- Hill cards are implemented in [`HillCalloutView`](./MapHills/Core/Overlays/PeakCalloutsAndGPX.swift:19)
- Start point cards are implemented in [`StartPlaceCalloutView`](./MapHills/Core/Overlays/PeakCalloutsAndGPX.swift:568)
- Cached area cards are implemented separately in [`CachedAreaCalloutView`](./MapHills/Core/Overlays/CachedAreaCalloutView.swift:1)

The map controller routes selection into those views in:

- [`MapViewController+Annotations.swift`](./MapHills/Core/Map/MapViewController+Annotations.swift:18)
- [`MapViewController.swift`](./MapHills/Core/Map/MapViewController.swift:2424)
- [`MapViewController.swift`](./MapHills/Core/Map/MapViewController.swift:2503)
- [`MapViewController.swift`](./MapHills/Core/Map/MapViewController.swift:2914)

### Current Placement Behavior

#### Hills

When a hill is selected:

- The app dismisses any open hill/start/cached callouts.
- The selected peak is reloaded and then shown in `HillCalloutView`.
- `showHillCallout(...)` passes a placement mode that defaults to `.automatic`.
- In search flows, the selected hill is repositioned so it lands around one-third from the top of the screen before the callout opens.

Key code paths:

- [`focusOnPeak(...)`](./MapHills/Core/Map/MapViewController.swift:1882) recenters the map and optionally calls `positionCoordinateForCallout(...)`.
- [`positionCoordinateForCallout(...)`](./MapHills/Core/Map/MapViewController.swift:1926) explicitly targets `mapView.bounds.minY + (mapView.bounds.height / 3.0)`.
- [`showHillCallout(...)`](./MapHills/Core/Map/MapViewController.swift:2424) builds the card.
- [`HillCalloutView.presentCallout(...)`](./MapHills/Core/Overlays/PeakCalloutsAndGPX.swift:439) chooses between side placement and above/below placement.

#### Start points

When a start point is selected:

- The app uses the same general selection flow.
- `showStartPlaceCallout(...)` defaults to `.automatic`.
- Search-mode start point selection uses `.belowAnchor` and explicitly repositions the map with `positionCoordinateForCallout(...)`.

Key code paths:

- [`focusOnStartPlace(...)`](./MapHills/Core/Map/MapViewController.swift:2914)
- [`showStartPlaceCallout(...)`](./MapHills/Core/Map/MapViewController.swift:2503)
- [`MapViewController+HillSearch.swift`](./MapHills/Core/Map/MapViewController+HillSearch.swift:147)

#### Why The Behavior Feels Inconsistent

The inconsistency is not accidental. It comes from different rules for different entry points:

- Search results force a below-anchor presentation and recenter the map.
- Direct tap selection uses automatic placement.
- The automatic hill and start point layouts have different widths, reserved edge rails, gaps, and height rules.
- Hill cards and start point cards also have different content density, so they hit scroll thresholds at different times.

Specific layout differences:

- Hill cards cap width at about `280pt` and reserve fixed left/right rail widths in [`HillCalloutView.presentCallout`](./MapHills/Core/Overlays/PeakCalloutsAndGPX.swift:439).
- Start point cards cap width at about `320pt` and use a different reserved-space policy in [`StartPlaceCalloutView.presentCallout`](./MapHills/Core/Overlays/PeakCalloutsAndGPX.swift:958).
- Hill cards use a `56pt` automatic vertical gap; start point cards also use `56pt` but a different decision tree.
- Hill cards place the callout either above or below and may add start-place actions as an additional section.
- Start point cards often carry more content, including walk summaries and nearby hills, so they scroll sooner.

### Recommendation

#### A. Make below-anchor the default presentation for both card types

If the user taps a hill or start place, the most stable behavior is:

- reposition the map so the selected point lands at roughly one-third of the screen height
- open the card beneath that point
- only allow the card to open above the point when there is a hard space constraint

This is already close to what search does in some flows. The key change is to make it the default everywhere, not just in search-driven flows.

#### B. Unify the placement policy

The app should have one placement policy shared by hills and start places:

- same anchor fraction
- same below-anchor gap
- same fallback threshold
- same left/right edge clamping
- same maximum card width unless there is a feature-specific reason to diverge

That would remove most of the visible variance without changing the content.

#### C. Reduce scrollbars by reserving more screen space up front

The current cards scroll because the content is allowed to become taller than the available space.

To reduce scrolling:

- move the selected point before presentation so the card has more room below it
- use the below-anchor placement as the first choice
- keep the card height flexible only until a shared maximum
- let scrolling happen only when content genuinely exceeds the remaining space

That matches your ideal outcome: the point moves up, the card opens below, and scrollbars only appear when content truly overflows.

#### D. Consider a shared callout sizing helper

Right now, hill and start point callouts calculate size independently. A shared helper should own:

- preferred width
- fitted height
- minimum height
- maximum height
- scroll activation threshold

This would make both card types behave predictably at the same device size and map zoom.

#### E. Keep content, but make the layout more compact

You said the content is fine, so I would not redesign the data model first. Instead:

- keep the same fields
- tighten padding and section spacing
- standardize row heights
- remove unnecessary vertical duplication

That gives you more usable space before scroll behavior starts.

#### F. Normalize the selection flow

The selection flow should not change because the user came from search versus direct tap unless there is a deliberate reason.

Recommended policy:

1. Tap or search selects the annotation.
2. Map recenters if needed.
3. Card opens below the selection.
4. Card scrolls only if it cannot fit after recentering.

That would make the behavior much easier to explain and debug.

## Recommended Implementation Order

1. Create a shared overlay chrome/style helper and align the generic dialog primitives first.
2. Standardize dialog copy and action semantics across the app.
3. Introduce a shared callout placement helper for hills and start points.
4. Change all hill/start-point entry points to use the same below-anchor default.
5. Tighten the callout sizing rules so scroll only appears on genuine overflow.

## Bottom Line

The app already has a strong custom-dialog foundation, but the current implementation is too local and too feature-specific. The fastest way to improve consistency is to standardize the shared primitives first, then collapse hill/start-point placement onto one shared rule set.

For the hill and start point cards, the clearest fix is to make the map repositioning behavior universal instead of conditional. That will make the cards feel intentional rather than opportunistic, and it should reduce unwanted scroll behavior significantly.
