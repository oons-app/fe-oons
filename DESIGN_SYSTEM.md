# Ons design system (v2)

One visual language for the provider app, built on the palette the customer app already uses.
Code lives in `lib/ds/`. Import `package:oons/ds/ds.dart` and nothing else.

**Living guide:** run a debug/profile build and open `/ds` — every token and every primitive, rendered for real, in Arabic or English. If a component is not in the gallery it is not part of the system.

## Rules that never bend

1. **Square.** Border radius is `0` everywhere — cards, buttons, chips, inputs, sheets, switches, badges. No shadows on UI.
2. **One border.** Cards are white with a `1px` ink border. Rows *inside* a card are separated by a `1px` divider, never by more cards.
3. **Two backgrounds per screen** at most (cream + white/surface).
4. **Colour means something.** Olive = safe/done/verified only. Terracotta = needs attention only, never decoration. Colour is never the only signal — the label says it too.
5. **Numbers are mono + Arabic-Indic.** Every price, time, count and percentage is IBM Plex Mono, shown as `٠١٢٣٤٥٦٧٨٩` in Arabic. Latin digits only for booking IDs, a status-bar clock, coupon codes and URLs. Use `DsFormat`, never string interpolation.
6. **Icons come from the Ons set** (24 grid, 2px stroke, square caps, miter joins, no fill, inherit text colour). An icon sits next to a label, except: close, back, plus, minus, search, bell, camera, advance — and those carry an accessible name (`OnsIconOnly`).
7. **44px minimum hit target.** Text contrast ≥ 4.5:1.
8. **Every empty state has one real action.** No illustrations, no "عفواً".
9. **Saves are automatic where the change is small** (a toggle, a chip): optimistic update → toast «اتحفظ» → roll back with an error toast if the server says no.

## Tokens (`Ds`)

| token | hex | use |
|---|---|---|
| `cream` | `#F7F4EE` | screen background |
| `surface` | `#EFE9E2` | inner boxes, time column, icon tiles, "off" tracks |
| `white` | `#FFFFFF` | cards, fields |
| `ink` | `#1C1518` | text, primary borders |
| `plum` / `plumPressed` | `#3E2136` / `#2A1622` | primary, selected, main button |
| `plumLight` | `#F0E6EE` | selected background, tags |
| `olive` / `oliveText` | `#6B7355` / `#4E5540` | safe, done, verified |
| `terracotta` / `terracottaBg` / `terracottaText` | `#B5654B` / `#F6E7E1` / `#8E4B36` | needs attention |
| `neutral` | `#EDE6E0` | cancelled / draft tag |
| `divider` | `#DCD4CC` | inner row dividers |
| `textBody` / `textMuted` / `textFaint` | `#4A3F45` / `#6E655F` / `#9A928C` | descriptions / meta / hints, disabled |
| `scrim` | ink @ 42% | modal scrim |

Space `s1..s8` = 4 · 8 · 12 · 16 · 20 · 24 · 32. Page gutter `Ds.gutter` = 20.
`test/ds_test.dart` fails if these ever drift from the customer app's `T` / `Client` palette.

## Type (`DsText`)

IBM Plex Sans Arabic (Arabic) / Archivo (English) come from the theme; numbers are IBM Plex Mono.

| style | size / weight |
|---|---|
| `screenTitle` | 30 / 700 |
| `subTitle` | 26 / 700 |
| `section` | 16 / 700 |
| `itemName` | 15 / 700 |
| `body` | 13.5 / 400 |
| `meta` | 12.5 / 400 |
| `hint` | 12 / 400 |
| `button` | 16 / 700 |
| `num(size, weight, color)` | Plex Mono 500/600 |

## Formatting (`DsFormat`)

`digits`, `price` (`١,٢٠٠ ج.م`), `pricePiastres`, `amount`, `time` (`٠٩:٠٠`), `percent`, `range`, `duration`, `durationShort`, and Arabic-agreement counters: `specialties`, `services`, `visits`, `tasks`, `days` (1 → «تخصص واحد», 2 → «تخصصين», 3–10 → «٥ تخصصات», 11+ → «١١ تخصص»).

## Components

| component | what it is |
|---|---|
| `DsButton` | primary (54px plum, label + trailing icon), secondary (white + ink border), danger (terracotta-light). `compact` = 46px, `busy` = spinner in the button and no second tap |
| `DsTextLink` | underlined 1px link; `danger` for terracotta |
| `DsSegmented` | bordered row; selected cell plum/cream, hairline between cells |
| `DsChip` | toggle; on = plum/cream, off = white/ink; `mono` for hours, `compact` to fit seven on a row |
| `DsSwitch` | square 44×24, square knob, plum track when on; always give it a `label` |
| `DsStatusBadge` | mono 10.5 bordered; `DsTone.olive` / `neutral` / `attention` |
| `DsTag` | small plum-light label («باقة») |
| `DsCard` · `DsCard.rows` | white + ink border; rows variant divides children with hairlines |
| `DsListRow` | icon · label · value · chevron, 56px, `danger` |
| `DsSectionHeader` | title + action link or meta |
| `DsStatStrip` | one bordered strip of stats, last cell plum-light |
| `DsMeter` | determinate bar, ink border, plum fill |
| `DsIconTile` | 46px surface square with a 22px grey icon |
| `DsKicker` | mono caps label |
| `showDsSheet` | cream bottom sheet, ink top border, × button, 42% scrim |
| `DsEmptyState` | tile → fact → why → one action (+ link) |
| `DsToast.show` | ink toast, check icon, 1.8s, never takes a tap |
| `DsBackHeader` | 40px bordered back square + breadcrumb |
| `DsField` | labelled field; `mono` for numbers, `ltr` for phones/URLs |
| `DsSkeleton` · `DsSkeletonRows` | pulsing blocks shaped like the real rows |
| `DsBottomNav` | icon + label, 3px plum bar on the active tab |

## Patterns

- **Loading:** skeletons shaped like the rows for lists; a spinner *inside* the button for actions over 1s; never a full-screen spinner for a small action.
- **Optimistic toggle:** apply → `PATCH` just that field → `DsToast.show(context, 'اتحفظ')`; on failure revert and `DsToast.show(..., error: true)`. (`lib/features/pro/v2/autosave.dart`)
- **RTL first:** use `EdgeInsetsDirectional` / `AlignmentDirectional`; arrows mirror through the icon set, never by flipping a whole widget.
- **Copy:** Egyptian colloquial, feminine address, short sentences, «إنستاباي» not "InstaPay".

## Where it is used: the provider app (v2)

| surface | file |
|---|---|
| bottom nav + cross-tab jumps (`ProNav`) | `lib/app/shell.dart`, `lib/features/pro/v2/pro_nav.dart` |
| الزيارات | `v2/visits_tab.dart` — stats, seven-day strip, cards, past list |
| خدماتي | `v2/services_tab.dart` (+ `areas_hours.dart`, `specialty_page.dart`, `service_sheet.dart`, `tiers_sheet.dart`, `request_specialty.dart`) |
| الأرباح | `v2/earnings_tab.dart` |
| حسابي | `v2/account_tab.dart`, `link_page.dart`, `details_page.dart`, `legal_page.dart`, `plans_route.dart` |
| auto-save | `v2/autosave.dart` (`AutosaveQueue`, `ProAutosave`) |
| grouping (category → specialty → service) | `v2/services_model.dart` |
| strings | `lib/l10n/pro_v2_copy.dart`, registered as `Copy.of(lang)['pv2']` |

Older widgets keep their names but are adapters over this system: `Pro*` (`pro_chrome.dart`) and the plan wizard's `Wiz` tokens now resolve to `Ds` values. New code uses `Ds*` directly.

Mapping to the backend: the prototype's **category** is a vertical (`cleaning`, `beauty`, `chef`), its **specialty** is a backend `Category`, its **service** is a `ServiceItem`. Area-priced cleaning packages (`kind: cleaning`) are the **tiers** table of a specialty.

## Where it is used: the Ops Console (bo.oons.app)

`lib/admin_v2` runs on this system too — same rules, same palette, no palette of its own.

| layer | file | what it does |
|---|---|---|
| tokens | `admin_v2/theme/tokens.dart` (`Ops`) | every name the console already used (`Ops.card`, `Ops.plum`…) now **resolves to `Ds`**; all `Ops.radius*` are `0`; `Ops.border` is the ink rule, `Ops.borderSoft` the row hairline; `Ops.cardBox()` is `Ds.card()` |
| Material theme | `admin_v2/theme/theme.dart` | square inputs/buttons/dialogs/menus, ink borders, plum primary, no elevation, no splash; Archivo (EN) / IBM Plex Sans Arabic (AR) |
| atoms | `admin_v2/ui/atoms.dart` | `V2StatusPill` = `DsStatusBadge` (mono, bordered), `V2FilterChip`/`V2Pill` = `DsChip`, `V2Card`/`V2SectionCard` = `DsCard`, `V2MiniBar` = `DsMeter`, tab bar = 3px plum underline |
| buttons | `admin_v2/ui/buttons.dart` | `V2Btn`: primary plum · ghost white + ink border · danger terracotta-light; 44px (`sm` 38, table-row 32) |
| table / list | `admin_v2/ui/grid_table.dart`, `list_view.dart` | white card with ink border, surface header over an ink rule, `divider` row hairlines, row actions wrap instead of overflowing |
| chrome | `admin_v2/chrome/*` | plum sidebar with the 3px "you are here" bar, cream header (stacks title over controls below 760px), square modal on the 42% scrim, ink toast with Ons check icon |

**Tone mapping.** The console keeps its six `V2Tone`s; the system has three meanings:
`ok` → olive (done / verified) · `warn` and `bad` → terracotta (needs attention) · `plum`, `info`, `neutral` stay quiet.
The pill's label always says what the colour means.

**Rules for new console code.** Read colour/size from `Ops` / `Ds`; never write a hex, a `BorderRadius.circular(n)`, a `BoxShadow` or `BoxShape.circle`
(`test/admin_v2_ds_test.dart` scans `lib/admin_v2` and fails). Use `V2Btn`, `V2Card`, `V2StatusPill`, `V2FilterChip` — not raw Material buttons.
Icons: `OnsIcon` where the set has one (close, search, check, retry, pin, alert).

**Console-only exceptions.** It is a pointer-driven desktop tool: table-row actions are 32px, not 44px; ids, refs, dates and counts stay Latin-digit mono
(the rule already allows Latin for ids and codes); a few Material glyphs without an Ons equivalent (download, attach, sort arrows, visibility) remain.

## Adding to the system

1. Put the component in `lib/ds/primitives/`, export it from `ds.dart`.
2. Take every colour/size from `Ds` / `DsText`.
3. Add it to `lib/ds/gallery.dart` and a test to `test/ds_test.dart`.
4. Document it here.
