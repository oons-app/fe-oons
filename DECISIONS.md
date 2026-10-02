# Provider app prototype parity — gap decisions

Source of truth: `Service Provider App(2).html`. Stack: Flutter (`oonsa-ios`) + Go API (`oonsa-lightsail-src`).

## 1. Eligibility for تنظيف

Server returns `eligibleCategoryIds` on `GET /pro/catalog` (and approved categories on `/pro/categories`).  
Client **hides** ineligible category chips. Never show a save error for a category the UI never offered.

Eligibility rule (server): provider has an **active** `ProviderCategory` for that category (or legacy `Provider.Service` vertical match), plus vetted/ID-approved for cleaning vertical when enforced by ops flags.

## 2. Stable slugs / ids

Arabic labels stay in locale / `Loc` only.  
Cleaning tasks use ids like `cleaning.reception.chandelier`.  
Categories keep Mongo ObjectId + existing `slug` field.

## 3. Bulk price ±١٠٪

Never silently rewrite. Flow: confirm sheet (before → after per service) → apply → **10s undo toast** restoring previous prices.

## 4. Cleaning duration vs workers

Duration stays **provider-set**.  
UI shows a «مقترح» hint derived from size band × worker count; provider may override.

## 5. Per-tier task overrides

`excludedTaskIds` is stored **per cleaning ServiceItem (tier)**.  
Editor offers «طبّقيها على كل الشرايح» to copy exclusions onto all cleaning items.

## 6. New service names

No free-text live names.  
`POST /pro/catalog/name-requests` files a staff ticket. UI: «اطلبي اسم خدمة جديدة».

## 7. Strings / plurals / numerals

Pro screens: all user-visible strings via `Copy` (`lib/l10n/copy.dart`).  
Display: Arabic-Indic digits. Wire/API: Western digits.  
Helpers + unit tests for plurals (خدمة / عاملات / مهام) and digit conversion.

## 8. Offline, ID upload, push, analytics

Reuse existing packages. Analytics events: `pro_service_create|edit|delete|duplicate|bulk_price`.  
National ID: 14 digits + existing `POST /pro/id` review states.  
Push: existing device registration for new bookings.

## Commission preview

Net line: `round(price * (1 - displayRate)) + travelFee` (travel **not** commissioned).  
`displayRate` from catalog (default 0.10 for preview).  
Actual booking commission remains relationship-tier `commissionBps`.

---

# Cleaning subscriptions (pilot) — decisions

Source of truth: `Oons Cleaning Subscription.html` (customer, 8 screens) and `Subscription Plan Wizard.html` (provider). Stack: Flutter (this repo) + Go/Mongo API (`be-oons/server`). Flag: pilot settings doc (`enabled` + customer/provider allowlists), exposed to the app as `subscriptionsPilot` on `/me`.

## Stack
The brief describes an Expo/Fastify/Prisma monorepo. That is not this product, so the feature is built in the real stack. Money is stored in piastres; "integer EGP" rules are applied to the displayed/charged values.

## Pricing
- Fee = 10% of the subscription price, rounded to **whole EGP, half-up** (the prototype's `Math.round`). The customer pays price + fee; the provider receives the full price.
- One pricing function (`internal/subscribe/pricing.go`) feeds plan cards, the E1 badge, quote, hold, charge, receipt and renewal, so the bar, the pay button and the receipt can never disagree.
- Wizard plans price each line per visit (`subPrice`); monthly price = Σ qty × subPrice, always derived.
- A plan that costs the same or more than booking per visit is **allowed** (the wizard shows neutral copy); the customer UI hides the saving block when saving ≤ 0. A saving above `MaxSavingPct` (40) is rejected at publish.

## Scheduling and holds
- Cycle = 30 days from the first visit; ≥ 2 days between visits; lead 1 day; horizon 41 days; deep visits first. Rules are enforced server-side on quote, hold and subscribe; the client mirrors them only for instant feedback.
- Hold TTL is 15 minutes, refreshed on every change; abandoned holds expire and never lock the customer out.
- Reschedule and skip need ≥ 24 h notice. One skip per cycle; the make-up must be placed before `ends_on − 2 days` or it is forfeited (not refunded). Pause takes effect from the next cycle (max 2 cycles).
- Renewal: charge at `ends_on − 2 days` 10:00 Cairo, retry +1 d and +2 d, then `payment_failed` and no next cycle.
- Refund on cancel = per-visit price × visits not completed and > 48 h away (fee pro-rated). The cancel preview and the refund use one function.
- Address reveal: within 300 m of the pin, window −30/+90 min of the visit; revoked on complete (and never before the visit has had time to finish).

## Who picks the days, and half-day periods (overrides the wizard prototype)
Changed on the owner's instruction after the first build; the prototype is no longer the spec here.
- The weekdays a provider ticks in wizard step 3 are the days the **customer may choose from**, not the days she works (her own days off still apply on top). Empty list = every day. The customer calendar greys the other weekdays (`reason: "weekday"`, message «اليوم ده مش من الأيام المتاحة في الباقة دي.»); the server enforces it on quote, hold, create, reschedule, make-up and renewal.
- Publish needs the chosen days to be able to hold every visit: `days × 4 ≥ visits` (a weekday occurs ~4 times in 30 days). The wizard blocks it too; the old "≈ N visits a month" line is gone.
- A day has two periods, not free-form hours: **morning from 09:00** and **afternoon from 14:00** (Cairo wall clock; `MorningStart`/`AfternoonStart` in `config.go`). A period is free unless a booking overlaps it, so once one half is taken only the other is offered, and when both are the day is full. Long visits (> 5 h from 09:00) overlap the afternoon and take it too. Weekly mode keeps the same period every week; custom mode falls back to the free period with a message.
- Slots are stored UTC and Egypt changes its clocks on the last Thursday of October (inside the 41-day window), so weekly placement now carries a slot across dates by Cairo wall-clock time (`ShiftSlot`) — «الصبح» stays 09:00 on every week.
- Existing visits booked at other hours keep their time and show a plain clock label. Seeded demo plans now allow Saturday–Thursday.
- Not done: per-day period opt-out for a provider (both periods are always offered); per-member capacity.

## Copy
Subscription surfaces use the prototype's Egyptian Arabic **verbatim**, centralised (`customer_copy.dart`, `ar_eg.dart`) so the register can be switched in one place. This differs from the formal-MSA register used elsewhere in the customer app (commit `72b2fba`); it follows the brief ("Egyptian colloquial copy verbatim", "match the design 100%"). Flip it there if product prefers MSA.

## Open questions → config (all in `internal/subscribe/config.go`)
ServiceFeeRate .10, CycleDays 30, MinGapDays 2, LeadDays 1, HorizonDays 41, RescheduleCutoffHours 24, SkipCutoffHours 24, MaxSkipsPerCycle 1, MaxPauseCycles 2, MaxActivePlans 3, MaxSavingPct 40, ProviderCancelCreditEGP 100, AtRiskConsecutiveSkips 2 (**provisional rule**, labelled so in ops), HoldMinutes 15, RenewalLeadDays 2, RenewalNoticeDays 5, RefundCutoffHours 48. Also for product: a skipped visit not made up is forfeited (not refunded); the fee-explainer copy must match what the fee actually pays for; plan-version adoption needs ≥ 7 days' notice.

## مقترحات (not applied)
- Benefits are marketing text only; nothing enforces them (e.g. a free-reschedule benefit does nothing automatic).
- Capacity is per provider per day; per-member capacity is not modelled yet.
- No proration on mid-cycle subscribe (cycle starts at the first visit).
