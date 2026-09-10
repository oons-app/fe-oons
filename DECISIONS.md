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
