# Requirements Document

## Introduction

This spec covers a user-experience and product revamp of the CFT Calculator app (formerly "Wood CFT"), driven by owner feedback after seeing the first wired build on an Android emulator. The underlying domain, allocation, billing, and finalize/void engines are unchanged; this work reshapes the presentation layer, the navigation/information architecture, and adds two product capabilities: a unified order workflow with saveable orders and a home dashboard.

The changes are:

1. Rename the app to **CFT Calculator** (display name and launcher label) and set the launcher/app icon from the provided image.
2. Rework the **Receiving** screen to adjust quantities with +/- steppers instead of free-text entry, with an icon-only "add to inventory" action.
3. Rework the **Sell/Orders** screen so a staged line shows its exact CFT and can be increased/decreased after adding.
4. Unify **New order -> Review -> Invoice** into a single stepwise workflow, with the ability to save an in-progress order for later and resume it, and an order status progression (draft/review -> approved -> sold -> shared).
5. Make the **Price matrix** a vertical layout.
6. Add a **Home dashboard** showing available quantities per item, total sold, total amount (INR), and previous orders.
7. Restructure the **bottom navigation** to Stock / Orders / Home / Bills, and move **Settings** to a top-right action.

The app continues to run against the local SQLite cache for catalog/stock and the in-memory hosted-store fakes for finalize/sync (the real Supabase backend is a separate spec). To make the dashboard and order history meaningful before Supabase, finalized sales and saved orders are persisted in the local database.

All existing behavior guarantees (exact arithmetic, meet-or-exceed allocation, GST/loading rules, immutable invoice snapshots, idempotent finalize/void) are preserved. The existing automated test suite must remain green; new UI and persistence work adds its own tests.

## Glossary

- **CFT Calculator**: The application's new display name (formerly "Wood CFT").
- **App_Icon**: The launcher icon and in-app brand mark, sourced from the provided image file `wmremove-transformed.jpeg`.
- **Stepper**: A +/- control that increments/decrements a whole count, with the current value also directly editable.
- **Order**: A customer demand being built in the Orders tab; it has staged lines and a status.
- **Order_Status**: The lifecycle state of an Order: `draft` (being built / saved for later), `approved` (reviewed and confirmed), `sold` (finalized -> stock deducted, sale recorded), `shared` (bill exported/shared).
- **Saved_Order**: An Order persisted locally in `draft` status so it can be resumed later from the Orders tab.
- **Sale**: A locally persisted record of a finalized (sold) Order, used by the dashboard and bills history (independent of, and later reconciled with, the hosted Sales store).
- **Dashboard**: The Home tab surface summarizing stock on hand, totals sold, total amount, and recent orders.
- **Stock_Tab / Orders_Tab / Home_Tab / Bills_Tab**: The four bottom-navigation destinations.

## Confirmed Decisions

- **CD-1**: App display name and launcher label become **CFT Calculator**.
- **CD-2**: The launcher icon is generated from `wmremove-transformed.jpeg` (converted to the required icon formats/sizes).
- **CD-3**: Bottom navigation is **Stock / Orders / Home / Bills** (four tabs). **Settings** is NOT a bottom tab; it is a top-right action (gear icon).
- **CD-4**: The Receiving length-grid uses **Steppers** (+/-) per length; the "add to inventory" control is an **icon button**.
- **CD-5**: A staged order line shows its **exact CFT** and supports **increase/decrease after adding** (not remove-and-re-add).
- **CD-6**: New order, allocation review, and invoice preview are a **single linear workflow** (next/back), not three disconnected screens.
- **CD-7**: The Price matrix is laid out **vertically**.
- **CD-8**: The underlying domain/application engines and their contracts are **unchanged**; this is presentation + navigation + two new persisted capabilities.
- **CD-9**: The existing automated test suite stays green; new work is covered by new tests.

## Requirements

### Requirement 1: Rebrand to CFT Calculator with app icon

**User Story:** As the owner, I want the app named "CFT Calculator" with a proper icon, so that it looks finished and identifiable on the device.

#### Acceptance Criteria

1. The System SHALL display the app name as "CFT Calculator" wherever the app title is shown (home/dashboard header, task-switcher title).
2. The launcher label on the device home screen SHALL read "CFT Calculator".
3. The System SHALL set the launcher App_Icon from the provided image, generated into the icon sizes/formats the target platforms require.
4. WHERE a brand mark is shown in-app (e.g. the dashboard header) THE System SHALL use the same App_Icon image.
5. The rename SHALL NOT break existing references to the internal package name; only the user-visible name and icon change.

### Requirement 2: Receiving via +/- steppers with an icon action

**User Story:** As the owner, I want to add or remove bunches/pieces with +/- buttons instead of typing a number, so that receiving stock is faster and less error-prone.

#### Acceptance Criteria

1. WHERE the Receiving screen lists lengths (2-9 ft) THE System SHALL present each length with a Stepper (a decrement button, the current count, and an increment button) instead of a free-text field.
2. WHEN the owner taps increment or decrement THEN the System SHALL change that length's count by one unit (one bunch for reapers, one piece for planks) and never below zero.
3. WHERE direct entry is useful THE current value in the Stepper SHALL be tappable to type an exact whole count (so large quantities do not require many taps).
4. The "add to inventory" action SHALL be an icon button (an appropriate, labelled-for-accessibility icon) rather than a text button.
5. WHEN the owner activates the add-to-inventory action THEN the System SHALL record the entered quantities exactly as today (immediate local commit, pending until sync), preserving all current receiving behavior and the negative-stock guard.
6. Every Stepper control SHALL meet the 44x44 pt minimum touch target and expose accessible labels and the unit (bunches/pieces).

### Requirement 3: Adjustable staged order lines showing exact CFT

**User Story:** As the owner, while building an order I want to see each line's exact CFT and change its quantity in place, so that I can tune the order without deleting and re-adding lines.

#### Acceptance Criteria

1. WHERE a staged order line is shown THE System SHALL display its exact CFT (4-dp display of the exact value) alongside its variety, cross-section, length, and unit count.
2. WHERE a staged line has an adjustable quantity THE System SHALL present +/- Steppers to increase or decrease the line's quantity in place.
3. WHEN the owner changes a staged line's quantity THEN the System SHALL recompute and show that line's exact CFT immediately, using the shared calculation engine (no float drift).
4. WHEN a staged line's quantity would drop to zero via decrement THEN the System SHALL remove the line (or require an explicit remove), never leaving a zero-quantity line.
5. The order summary SHALL show the running total exact CFT across staged lines and update as lines change.

### Requirement 4: Unified order workflow with saveable orders

**User Story:** As the owner, I want building, reviewing, and billing an order to be one guided flow, and I want to save an unfinished order to finish later, so that the selling process is coherent and interruptible.

#### Acceptance Criteria

1. The Orders flow SHALL proceed as linear steps: build (select items) -> review allocation (picking list) -> invoice preview -> finalize (sold) -> share, with forward and backward navigation between steps.
2. WHERE the order is incomplete THE System SHALL let the owner save it as a Saved_Order in `draft` status.
3. WHEN the owner opens the Orders tab THEN the System SHALL list resumable Saved_Orders in `draft`/`review` status so the owner can continue one later.
4. A Saved_Order SHALL persist locally so it survives app restart (OD-1).
5. WHEN the owner advances past review THEN the Order_Status SHALL become `approved`; WHEN finalize succeeds THEN it SHALL become `sold` and the System SHALL deduct stock and record a Sale, exactly once (idempotent), reusing the existing finalize transaction (OD-2).
6. WHEN the owner shares the bill THEN the Order_Status SHALL reflect `shared`; sharing SHALL NOT mutate stock or re-finalize (snapshot immutability preserved).
7. WHERE finalize is not permitted (missing rate, insufficient stock, or offline/no-session once Supabase is wired) THE System SHALL block `sold` with a clear reason and keep the order resumable.

### Requirement 5: Vertical price matrix

**User Story:** As the owner, I want the price matrix laid out vertically, so that it is easier to read and edit on a phone.

#### Acceptance Criteria

1. The Price matrix SHALL present rates in a vertical layout (one variety x cross-section rate per row, scrolling vertically) rather than a horizontally-scrolling grid.
2. The vertical layout SHALL preserve all current editing behavior: entering/clearing a rate, the missing-rate marker, and persistence through the pricing service.
3. Each editable rate row SHALL meet the 44x44 pt touch target and show the variety and cross-section it applies to.

### Requirement 6: Home dashboard

**User Story:** As the owner, I want a home screen that shows my stock, how much I have sold, the money total, and recent orders, so that I can see the state of the business at a glance.

#### Acceptance Criteria

1. The Home_Tab SHALL be the default tab shown after first-run setup (OD-3).
2. The Dashboard SHALL show available (confirmed) quantities per stock item, grouped readably, with explicit unit labels.
3. The Dashboard SHALL show a total count/volume sold and a total amount in INR (OD-4 defines the period; default all-time).
4. The Dashboard SHALL list previous orders (recent Sales / finalized orders), most recent first, each showing its identity, total, and date.
5. WHERE sold data is required THE System SHALL read it from locally persisted Sales so the dashboard is meaningful before the Supabase backend exists.
6. The Dashboard SHALL update to reflect new stock and new sales when the owner returns to it.
7. The Dashboard header SHALL show the CFT Calculator brand mark and a top-right Settings action.

### Requirement 7: Navigation restructure (Stock / Orders / Home / Bills; Settings top-right)

**User Story:** As the owner, I want the main tabs to be Stock, Orders, Home, and Bills with Settings tucked in the corner, so that the primary actions are front and center.

#### Acceptance Criteria

1. The bottom navigation SHALL present exactly four tabs: Stock, Orders, Home, Bills, each with an appropriate icon and label.
2. Settings SHALL NOT be a bottom tab; it SHALL be reachable from a top-right action (gear icon) on the Home_Tab (and/or a consistent location) that pushes the existing Settings surface.
3. The Orders_Tab SHALL host the unified order workflow and the list of Saved_Orders (Requirement 4).
4. The Stock_Tab SHALL continue to host inventory browsing and receiving.
5. The Bills_Tab SHALL host finalized bills / invoice history.
6. Switching tabs SHALL preserve each tab's own navigation stack (per-tab navigator), consistent with the current shell.

### Requirement 8: Non-regression and test coverage

**User Story:** As the developer, I want the revamp to not break existing behavior, so that the correctness guarantees still hold.

#### Acceptance Criteria

1. WHEN `flutter analyze` runs THEN it SHALL report no issues after the revamp.
2. WHEN `flutter test` runs THEN all pre-existing domain/application/property/integration tests SHALL still pass.
3. New UI surfaces (steppers, adjustable lines, vertical price matrix, dashboard, nav) SHALL have widget tests.
4. New persisted capabilities (Saved_Order, local Sale) SHALL have unit tests covering create/resume/finalize and the dashboard aggregates.
5. The revamp SHALL NOT weaken the existing property, integration, or smoke tests.

## Assumptions & Open Decisions Register

- **OD-1 (Saved order persistence):** Assumed Saved_Orders persist in the local drift database (survive restart) as a new table. _Default adopted; confirm in design._
- **OD-2 ("Sold" == finalize):** Assumed marking an order `sold` triggers the existing finalize transaction (stock deduction + Sale record), idempotent under an order-scoped key. _Default adopted; confirm._
- **OD-3 (Default tab):** Assumed Home is the default landing tab after first-run. _Default adopted; confirm._
- **OD-4 (Dashboard period):** Assumed totals are all-time; a date filter (today/this month) is a possible later enhancement. _Default adopted._
- **OD-5 (Stepper direct entry):** Assumed the stepper's number is tappable to type an exact count, in addition to +/-. _Default adopted._
- **OD-6 (Icon tooling):** Assumed `flutter_launcher_icons` generates the launcher icon from a PNG converted from the provided JPEG. _Default adopted._
- **OD-7 (Orders == renamed Sell):** Assumed the Orders tab replaces/renames the former Sell tab and absorbs its screens. _Default adopted._
- **OD-8 (Bills history source):** The Bills tab lists finalized bills from the locally persisted Sales until Supabase is wired. _Default adopted._
