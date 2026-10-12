# Requirements Document

## Introduction

Wood CFT is a single-user, single-device iPhone application for an owner-operated timber and plywood business. The application manages a product catalog, truck/inventory receiving, stock ledger, deterministic order allocation, GST-aware billing, and invoice export (editable Word document and formatted WhatsApp text). Its authoritative data store is a hosted managed database (Supabase preferred; Neon an allowed alternative), fronted by a local SQLite cache and a durable local queue for pending operations. Calculations, cached inventory browsing, receiving entry, and drafts work offline against the local cache and queue; finalized billing requires cloud confirmation (an authenticated hosted-database transaction) and therefore requires connectivity.

The application is built in Flutter/Dart using Cupertino (Apple Human Interface Guidelines) native controls. It is compiled for a physical iPhone through a hosted macOS continuous-integration pipeline with code signing disabled, producing an unsigned IPA that the owner sideloads using a free Apple account via Sideloadly. The owner edits source and runs domain tests on a Windows laptop.

The first release handles **rectangular timber only**. Plywood support is deferred to a later release. All measurement, allocation, and money computations use exact rational/decimal arithmetic to avoid floating-point drift; display rounding is strictly presentational and never alters stored volume, allocation outcomes, loading-tier comparisons, or money.

The scope of this document is the complete set of requirements for version 1. Where a business decision is settled by the owner it is captured as a confirmed decision; where a decision remains provisional it is captured in the Assumptions & Open Decisions Register with a documented default so implementation can proceed without blocking.

## Glossary

- **System**: The Wood CFT iPhone application as a whole, including its hosted authoritative data store together with its on-device local cache and pending-operation queue.
- **Hosted_Database**: The authoritative managed database (Supabase preferred, Neon allowed) that holds the system of record.
- **Local_Cache**: The on-device SQLite copy used for offline calculation, inventory browsing, receiving entry, and drafts.
- **Pending_Operation_Queue**: A durable local queue of not-yet-synchronized operations, each carrying a stable Idempotency_Key.
- **Pending_Receiving_Stock**: Received quantities saved locally but not yet synchronized and confirmed to the Hosted_Database; not sellable until confirmed.
- **Confirmed_Available_Stock**: Stock confirmed in the Hosted_Database and eligible for sale and finalization.
- **Authenticated_Session**: An authenticated owner session required for privileged Hosted_Database access.
- **Catalog**: The persisted set of varieties and cross-sections available for stock and sale.
- **Variety**: A named timber type (e.g., Mahogany, Kalani, Palajathi). Varieties may be added, renamed, or deactivated.
- **Cross_Section**: A width-by-thickness profile measured in inches (e.g., 2 × 1 in). The first value is width; the second value is thickness (the owner also calls these "width" and "breadth").
- **Width_In**: The first cross-section dimension, in inches.
- **Thickness_In**: The second cross-section dimension, in inches, used in the volume formula.
- **Length_Ft**: The length of a piece, in feet (range 2 ft to 9 ft).
- **Category**: A classification of a cross-section as Reaper or Plank (stored as metadata).
- **Reaper**: A cross-section classified as a reaper. Reapers are received, allocated, and sold in whole bunches of exactly 10 pieces only.
- **Plank**: A cross-section classified as a plank. Planks are received, allocated, and sold in whole pieces.
- **Bunch**: A unit of exactly 10 reaper pieces.
- **Piece**: A single physical length of timber.
- **CFT**: Cubic feet, the volume measure used for pricing and reporting.
- **CFT_Per_Piece**: Volume of one piece, computed as Width_In × Thickness_In × Length_Ft ÷ 144.
- **Stock_Item**: A persisted inventory record keyed by the combination of Variety, Cross_Section, and Length_Ft, holding an available quantity.
- **Receipt**: A truck/inventory receiving session that records incoming stock.
- **Price_Matrix**: The editable table of selling rates indexed by Variety × Cross_Section.
- **Rate**: Selling price in Indian Rupees (INR, ₹) per CFT, exclusive of GST, dependent on Variety and Cross_Section only (independent of length).
- **Order_Request**: A structured customer demand entered by the owner, of one of four defined request types.
- **Allocation**: The deterministic selection of Stock_Items and quantities that satisfies an Order_Request within hard constraints.
- **Line**: A single allocated or billed row (one Stock_Item and a quantity).
- **Goods_Subtotal**: The sum of rounded line amounts for all goods lines, excluding tax and loading.
- **Taxable_Subtotal**: The subtotal on which tax is computed; equals Goods_Subtotal (loading excluded).
- **Loading_Charge**: A flat charge added once per order after tax, based on total sold CFT.
- **Tax_Rate_Mode**: The literal total tax rate applied to the Taxable_Subtotal: No GST, 9% total, or 18% total, shown as a single tax line.
- **Invoice**: A finalized bill with an immutable snapshot of lines, rates, tax, loading, and totals, and a permanent invoice number.
- **Invoice_Snapshot**: The immutable persisted record of all values used to produce an Invoice.
- **Void**: A recorded reversal of a finalized Invoice that restores stock exactly once and retains the original.
- **Business_Profile**: The shop's own identity data: name, address, phone, optional logo, optional GSTIN, invoice prefix, and tax-invoice fields.
- **Backup**: A portable export of catalog, stock ledger, receipts, invoices, and settings.
- **Idempotency_Key**: A stable identifier that guarantees a repeated operation produces the effect exactly once; it is also used for synchronization and finalization retries.
- **Half_Up_Paise**: Rounding a monetary value to two decimal places (paise) using round-half-up.
- **Exact_CFT**: An unrounded rational CFT value used for allocation, loading-tier comparison, and totals.

## Requirements

### Requirement 1: Product Catalog Management

**User Story:** As the owner, I want to manage varieties and cross-sections, so that I can describe my timber accurately without losing historical accuracy.

#### Acceptance Criteria

1. THE System SHALL seed the Catalog with the varieties Mahogany, Kalani, and Palajathi, preserving the exact spelling as given.
2. THE System SHALL seed the cross-sections (Width_In × Thickness_In, in inches): 2 × 1 classified as Reaper, and 3 × 1, 4 × 1, 5 × 1, 6 × 1, and 7 × 1 classified as Plank.
3. THE System SHALL allow the owner to add a new Variety.
4. THE System SHALL allow the owner to rename an existing Variety.
5. THE System SHALL allow the owner to deactivate a Variety such that the deactivated Variety is unavailable for new receiving and new selling.
6. WHEN a Variety is renamed or deactivated, THE System SHALL retain each existing Invoice with the Variety name exactly as issued on that Invoice.
7. THE System SHALL NOT automatically merge two Varieties.
8. THE System SHALL display each Cross_Section using an inch label in the form "Width × Thickness in" (for example, "2 × 1 in").
9. THE System SHALL store the second cross-section dimension as the Thickness_In used in the volume formula.
10. THE System SHALL support Length_Ft values from 2 ft through 9 ft inclusive.
11. THE System SHALL store Width_In and Thickness_In in inches and Length_Ft in feet without interchanging the units.
12. WHEN the System is first initialized, THE System SHALL set every Stock_Item available quantity to zero and SHALL NOT create any fictional seed stock or seed prices.

### Requirement 2: CFT Volume Computation

**User Story:** As the owner, I want cubic-feet volumes computed exactly, so that quantities and bills are correct and free of rounding drift.

#### Acceptance Criteria

1. THE System SHALL compute CFT_Per_Piece as Width_In × Thickness_In × Length_Ft ÷ 144 using exact rational arithmetic.
2. THE System SHALL use the divisor 144 and SHALL NOT use the divisor 1728.
3. THE System SHALL compute the CFT of one Bunch as CFT_Per_Piece × 10.
4. THE System SHALL compute line CFT as CFT_Per_Piece × piece quantity.
5. THE System SHALL compute total CFT as the sum of the exact unrounded line CFT values.
6. WHEN CFT is displayed, THE System SHALL display CFT to 4 decimal places.
7. WHEN CFT is displayed to 4 decimal places, THE System SHALL NOT allow the displayed value to alter the stored Exact_CFT, allocation outcomes, loading-tier comparison, or any monetary result.

### Requirement 3: Reaper and Plank Sale Units

**User Story:** As the owner, I want reapers handled in bunches of ten and planks handled by the piece, so that allocation and billing match how I actually trade.

#### Acceptance Criteria

1. THE System SHALL allocate and sell Reaper stock in whole Bunches of exactly 10 pieces only.
2. THE System SHALL NOT allocate or sell Reaper stock as loose individual pieces.
3. THE System SHALL count and sell Plank stock by whole pieces.
4. WHERE a Reaper quantity is entered, THE System SHALL display the equivalent piece count alongside the Bunch count.

### Requirement 4: Pricing and the Price Matrix

**User Story:** As the owner, I want an editable price matrix keyed by variety and cross-section, so that I can set rates without the system guessing values.

#### Acceptance Criteria

1. THE System SHALL store a Rate as INR per CFT, exclusive of GST.
2. THE System SHALL determine a Rate from Variety and Cross_Section only and SHALL NOT vary the Rate by Length_Ft.
3. THE System SHALL present the Price_Matrix as an editable table of Varieties by Cross_Sections.
4. WHEN a new Variety is added, THE System SHALL create empty Rate entries for that Variety and SHALL NOT infer or guess any Rate.
5. THE System SHALL visibly indicate every missing Rate in the Price_Matrix.
6. THE System SHALL allow receiving stock for which a Rate is missing.
7. IF any sold Line lacks a valid Rate, THEN THE System SHALL block finalization of the Invoice.
8. WHEN an Invoice is finalized, THE System SHALL store the Rate and computed results as an immutable Invoice_Snapshot.
9. WHEN a Rate is changed after an Invoice is finalized, THE System SHALL NOT rewrite the finalized Invoice_Snapshot.

### Requirement 5: Inventory and Truck Receiving

**User Story:** As the owner, I want to record incoming truck stock quickly and safely, so that my inventory stays accurate even if the app closes mid-session.

#### Acceptance Criteria

1. THE System SHALL allow the owner to create a new Receipt or resume an existing active Receipt.
2. WHEN recording into a Receipt, THE System SHALL let the owner select a Variety and a Cross_Section, then enter quantities per Length_Ft from 2 ft through 9 ft.
3. WHILE a Variety and Cross_Section are selected, THE System SHALL keep that selection active across the compact length grid during quantity entry.
4. WHERE the selected Cross_Section is a Reaper, THE System SHALL accept input in Bunches and SHALL show the equivalent piece count.
5. WHERE the selected Cross_Section is a Plank, THE System SHALL accept input in pieces.
6. WHEN the owner records an explicit receiving entry, THE System SHALL persist that entry immediately to the Local_Cache within a single local transaction, enqueue it in the Pending_Operation_Queue for synchronization, and show the resulting quantity as Pending_Receiving_Stock until synchronization confirms it.
6a. THE System SHALL NOT allow Pending_Receiving_Stock to be sold before synchronization confirms it as Confirmed_Available_Stock.
7. WHEN the application is closed and reopened with an active Receipt, THE System SHALL recover the active Receipt.
8. THE System SHALL assign an Idempotency_Key to every receiving operation.
9. WHEN a receiving operation is retried, double-tapped, resumed, finished, or synchronized with the same Idempotency_Key, THE System SHALL apply the stock effect exactly once and SHALL NOT double-add stock, reusing the Idempotency_Key for sync retries.
10. THE System SHALL support opening-stock entry and SHALL support quantity adjustments that each record a reason.
11. THE System SHALL perform edits and undo through validated adjustment or reversal entries.
12. IF an adjustment or reversal would make a Stock_Item available quantity negative, THEN THE System SHALL block that adjustment or reversal.
13. THE System SHALL retain the full stock movement history.

### Requirement 6: Inventory Browser

**User Story:** As the owner, I want to browse and filter my inventory, so that I can see what I have in quantity and volume.

#### Acceptance Criteria

1. THE System SHALL allow filtering the inventory by Variety, Category, Cross_Section, and Length_Ft.
2. THE System SHALL display, for each Stock_Item, the available quantity and the available CFT.
3. THE System SHALL display inventory totals across the current filter.
4. WHERE the owner selects to show or hide zero-stock items, THE System SHALL apply that choice to the displayed inventory.
5. WHEN quantity and CFT are shown together, THE System SHALL display explicit unit labels for each.

### Requirement 7: Order Request Entry

**User Story:** As the owner, I want to enter customer demand in structured ways, so that I can request stock by quantity or by target CFT without free-text ambiguity.

#### Acceptance Criteria

1. THE System SHALL accept Order_Requests through structured entry only and SHALL NOT use natural-language or AI-based interpretation.
2. THE System SHALL support an Order_Request by exact quantity.
3. THE System SHALL support an Order_Request by target CFT with an exact Length_Ft.
4. THE System SHALL support an Order_Request by target CFT with an exact Cross_Section and flexible lengths.
5. THE System SHALL support an Order_Request by target CFT with a Category and flexible lengths.
6. THE System SHALL always compute the required quantity for a target-CFT Order_Request by rounding up so the allocation meets or exceeds the target, and SHALL NOT offer an at-most or a closest target option.

### Requirement 8: Deterministic Allocation

**User Story:** As the owner, I want allocation to be predictable and honest about stock, so that quotes reflect what I can actually supply.

#### Acceptance Criteria

1. THE System SHALL enforce as hard constraints any Length_Ft restriction, any Cross_Section restriction, the whole-unit rule (Bunches for Reaper, pieces for Plank), and stock availability.
2. WHEN allocating a target-CFT Order_Request, THE System SHALL compute unit counts as ceil(requested_CFT ÷ CFT_per_sale_unit) using exact arithmetic as the sole rule, where a sale unit is a complete Bunch for Reapers and a whole piece for Planks, applying the ceiling to unit counts and not to money.
3. THE System SHALL validate stock availability during allocation and SHALL NOT silently reduce a requested quantity.
4. IF available stock is insufficient to satisfy an Order_Request, THEN THE System SHALL produce a clearly labeled partial proposal that states the shortage and SHALL NOT label the result as fulfilled.
5. THE System SHALL bill the actual physical CFT allocated rather than the requested target CFT.
6. WHEN an Order_Request contains multiple Lines, THE System SHALL allocate each Line against the remaining availability so that no stock quantity is counted twice.
7. THE System SHALL apply allocation decisions in the following deterministic order: enforce hard constraints; always meet or exceed the target by rounding up (no selectable target direction) while minimizing the excess CFT; minimize deviation from the preferred length-group shares; then apply a documented stable tie-breaker of lower Length_Ft, then lower Stock_Item identifier.
8. THE System SHALL treat the 60/30/10 reaper length preferences (6-7 ft at 60%, 3-5 ft at 30%, 2 ft at 10%) as approximate stock-aware shares of allocated CFT and SHALL NOT treat them as an exact integer-Bunch guarantee.
9. THE System SHALL exclude 8 ft and 9 ft lengths from default flexible reaper allocation while keeping 8 ft and 9 ft available for explicit-length and manual allocation.
10. THE System SHALL apply flexible-length allocation to Reaper requests using the reaper length-group shares and SHALL NOT apply reaper length-group shares to Plank requests.
11. WHERE a Plank Order_Request uses flexible lengths, THE System SHALL allocate whole pieces, rounding up to meet or exceed the target while minimizing the excess CFT, and applying the documented stable tie-breaker of lower Length_Ft, then lower Stock_Item identifier.
12. THE System SHALL use a bounded heuristic allocation algorithm and SHALL NOT claim the allocation is optimal.

### Requirement 9: Monetary Computation and Display

**User Story:** As the owner, I want line amounts and totals computed exactly and displayed in Indian Rupees, so that my bills are correct and legible.

#### Acceptance Criteria

1. THE System SHALL compute each line amount from the actual allocated Exact_CFT multiplied by the Rate using decimal or rational arithmetic.
2. THE System SHALL round each line amount Half_Up_Paise.
3. THE System SHALL compute the Goods_Subtotal as the sum of the rounded line amounts.
4. THE System SHALL compute tax on the Taxable_Subtotal, which equals the Goods_Subtotal and excludes the Loading_Charge.
5. WHEN displaying a monetary value, THE System SHALL display INR with 2 decimal places and Indian digit grouping.
6. THE System SHALL compute total volumes by summing unrounded Exact_CFT values.

### Requirement 10: GST / Tax Computation

**User Story:** As the owner, I want a single literal tax line, so that my bill shows the exact total tax rate I choose.

#### Acceptance Criteria

1. THE System SHALL support the Tax_Rate_Modes No GST, 9% total, and 18% total.
2. THE System SHALL present the computed tax as a single tax line and SHALL NOT split tax into separate CGST and SGST lines.
3. WHEN a Tax_Rate_Mode of 9% total or 18% total is selected, THE System SHALL compute tax as the Taxable_Subtotal multiplied by the literal total rate.
4. THE System SHALL exclude the Loading_Charge from the Taxable_Subtotal.
5. WHEN the Tax_Rate_Mode is No GST, THE System SHALL compute zero tax.

### Requirement 11: Loading Charge

**User Story:** As the owner, I want a loading charge based on order size, so that larger orders carry the higher handling fee.

#### Acceptance Criteria

1. WHEN the actual total sold Exact_CFT of an order is less than 20, THE System SHALL set the Loading_Charge to ₹100.
2. WHEN the actual total sold Exact_CFT of an order is greater than or equal to 20, THE System SHALL set the Loading_Charge to ₹150.
3. THE System SHALL compare the exact total sold CFT against the 20 CFT threshold and SHALL NOT use the display-rounded CFT for the comparison.
4. THE System SHALL apply the Loading_Charge once per order.
5. THE System SHALL add the Loading_Charge after tax, so that the Loading_Charge is excluded from the taxable base.
6. WHERE the Tax_Rate_Mode is No GST, THE System SHALL still apply the Loading_Charge.
7. THE System SHALL NOT apply a Loading_Charge to a receiving operation, an empty order, or a cancelled order.

### Requirement 12: Billing Lifecycle and Finalization

**User Story:** As the owner, I want finalizing a bill to be atomic and idempotent, so that stock and invoice numbers never drift out of sync.

#### Acceptance Criteria

1. WHILE an order is in a calculating, draft, or preview state, THE System SHALL NOT deduct stock.
2. WHEN the owner finalizes an order, THE System SHALL require an Authenticated_Session and SHALL execute a single authenticated Hosted_Database transaction that validates all quantities and Rates against Confirmed_Available_Stock, writes the Invoice_Snapshots, allocates a permanent invoice number, and deducts stock atomically in the Hosted_Database.
3. THE System SHALL protect finalization with an Idempotency_Key such that repeated finalization of the same order produces exactly one Invoice and exactly one stock deduction.
3a. WHEN a finalize response is uncertain because the response is lost or the request times out, THE System SHALL retry with the same Idempotency_Key so that a lost response cannot create a duplicate Invoice or a duplicate deduction.
3b. IF connectivity or the Authenticated_Session is unavailable, THEN THE System SHALL NOT finalize and SHALL keep the order as a draft, while receiving, calculation, and draft editing remain available offline.
4. IF the finalization transaction fails, THEN THE System SHALL leave stock quantities and invoice numbering consistent with the pre-finalization state.
5. THE System SHALL NOT reserve stock for a draft order.
6. WHEN the owner finalizes a draft order, THE System SHALL revalidate Confirmed_Available_Stock availability in the Hosted_Database at the moment of finalization.
7. THE System SHALL retain each finalized Invoice as immutable with respect to later changes to the Catalog, Rates, Tax_Rate_Mode, or loading policy.

### Requirement 13: Invoice Correction (Void / Reversal)

**User Story:** As the owner, I want to correct a mistaken invoice through a recorded void, so that my records stay honest without deleting history.

#### Acceptance Criteria

1. THE System SHALL support correcting a finalized Invoice by recording a Void that restores the deducted stock exactly once.
2. THE System SHALL retain the original Invoice when a Void is recorded and SHALL NOT overwrite or delete the original Invoice.
3. THE System SHALL restore stock from a Void exactly once even if the Void operation is retried with the same Idempotency_Key.

### Requirement 14: Invoice Export — Editable Word Document

**User Story:** As the owner, I want to export a genuine editable Word document, so that I can share and adjust a professional invoice.

#### Acceptance Criteria

1. WHEN the owner exports an Invoice as a Word document, THE System SHALL produce a valid OOXML .docx file that opens as an editable document in the Flutter runtime.
2. THE System SHALL NOT satisfy the Word-document export by renaming a text or HTML file, and SHALL NOT satisfy it with a PDF-only output.
3. THE System SHALL generate the Word document from the same persisted Invoice_Snapshot used for the preview, so that the Word document values match the preview exactly.
4. THE System SHALL include in the Word document a business header, an invoice-and-customer block, an item table, and the totals.
5. WHEN an Invoice spans multiple pages, THE System SHALL repeat the header on each page of the Word document.
6. THE System SHALL give the Word document a human-readable filename.
7. THE System SHALL offer the Word document through the iOS share sheet and allow export to the Files app.

### Requirement 15: Invoice Export — WhatsApp Text

**User Story:** As the owner, I want a formatted WhatsApp text version of the bill, so that I can send a readable summary in chat.

#### Acceptance Criteria

1. WHEN the owner exports an Invoice as WhatsApp text, THE System SHALL produce human-readable formatted text generated from the same persisted Invoice_Snapshot used for the preview.
2. THE System SHALL format the WhatsApp text using simple headings, line breaks, and WhatsApp emphasis, and SHALL NOT use Markdown tables.
3. THE System SHALL ensure the WhatsApp text values match the preview exactly.
4. THE System SHALL provide the actions Share invoice file, Share bill text, and Copy bill text.
5. IF WhatsApp is not installed, THEN THE System SHALL offer the generic iOS share sheet.
6. THE System SHALL NOT re-deduct stock when sharing or exporting an Invoice.
7. WHERE a PDF export is provided, THE System SHALL provide it as an optional extra and SHALL NOT let it replace the Word-document or WhatsApp-text export.

### Requirement 16: Backup and Restore

**User Story:** As the owner, I want to back up and restore all my data, so that I do not lose records across updates or reinstalls.

#### Acceptance Criteria

1. THE System SHALL produce a portable Backup of the authoritative Hosted_Database data, together with the Local_Cache, containing the Catalog, stock ledger, Receipts, Invoices, and settings.
2. THE System SHALL preserve application data across ordinary application updates.
3. THE System SHALL provide an explicit Backup action before reinstalling.
4. WHEN restoring a Backup, THE System SHALL validate the Backup schema and version.
5. WHEN restoring a Backup, THE System SHALL NOT duplicate any stock movement.

### Requirement 17: iOS User Interface and Accessibility

**User Story:** As the owner, I want a native, accessible iPhone interface, so that the app is comfortable and usable in my shop.

#### Acceptance Criteria

1. THE System SHALL use Cupertino native controls consistent with the Apple Human Interface Guidelines.
2. THE System SHALL render SF Symbols through a supported bridge and SHALL provide a Cupertino fallback, recording the availability and the fallback used.
3. THE System SHALL provide touch targets of at least 44 × 44 points.
4. THE System SHALL support dynamic type and VoiceOver.
5. THE System SHALL NOT convey a stock shortage by color alone.
6. THE System SHALL display quantity and CFT together with explicit unit labels.
7. THE System SHALL support light and dark appearance using a restrained neutral theme with a single accent color and no wood photography.
8. THE System SHALL present bottom tabs for Stock, Sell, Bills, and Settings.
9. THE System SHALL make the Receive-stock action prominent on the Stock tab.
10. THE System SHALL provide a lightweight calculate-only action that does not affect inventory.
11. THE System SHALL provide a Settings area for varieties and sizes, the Price_Matrix, allocation policy, tax and loading policy, the Business_Profile, and backup and restore.
12. WHEN the application runs for the first time, THE System SHALL request only the configuration necessary to begin.
13. THE System SHALL allow receiving to begin before Rates are entered.
14. WHILE a sold Line is missing a Rate, THE System SHALL flag the missing Rate during selling.

### Requirement 18: Business Profile and Invoice Identity

**User Story:** As the owner, I want to configure my own shop identity, so that invoices represent my business accurately.

#### Acceptance Criteria

1. THE System SHALL allow the owner to configure the Business_Profile name, address, phone, optional logo, optional GSTIN, and invoice prefix.
2. THE System SHALL NOT assume the business name is "Zenith Systems".
3. THE System SHALL allow an optional customer name and phone for a simple sales bill.
4. WHERE a tax invoice is produced, THE System SHALL allow the GST identifiers, addresses, place-of-supply, and HSN to be configured.
5. THE System SHALL NOT fabricate registration details.
6. IF the configured tax-invoice fields are incomplete, THEN THE System SHALL NOT present the bill as a verified compliant tax invoice.

### Requirement 19: Data Architecture, Sync, and Authentication

**User Story:** As the owner, I want a hosted authoritative database with a reliable local cache and queue, so that I can work offline for everyday tasks while finalized bills are confirmed in the cloud exactly once.

#### Acceptance Criteria

1. THE System SHALL use a hosted managed database as the authoritative store, defaulting to Supabase with Neon as an allowed alternative.
2. THE System SHALL use a Local_Cache in SQLite and a durable Pending_Operation_Queue for offline calculation, inventory browsing, receiving entry, and drafts.
3. THE System SHALL require an Authenticated_Session for privileged Hosted_Database access.
4. WHERE Supabase is used, THE System SHALL enforce appropriate Row Level Security and SHALL use only client-safe configuration.
5. WHERE Neon is used, THE System SHALL access the Hosted_Database only through an authenticated API.
6. THE System SHALL NOT embed privileged database credentials or service-role keys in the application.
7. WHEN the owner records a receiving entry, THE System SHALL save the entry to the Local_Cache immediately and enqueue it for synchronization with a stable Idempotency_Key.
8. THE System SHALL distinguish Pending_Receiving_Stock from Confirmed_Available_Stock and SHALL NOT allow Pending_Receiving_Stock to be sold before synchronization confirms it.
9. WHEN synchronizing a queued operation, THE System SHALL use its Idempotency_Key so that a retried or duplicated operation is applied exactly once in the Hosted_Database.
10. WHEN a sync request outcome is uncertain because the response is lost or the request times out, THE System SHALL retry with the same Idempotency_Key and SHALL NOT create duplicate movements.
11. THE System SHALL allow calculations, cached browsing, receiving entry, and drafts to function offline, and THE System SHALL require cloud confirmation for finalized billing.

### Requirement 20: Build and Sideload Pipeline

**User Story:** As the owner, I want a repeatable macOS CI build that I can sideload, so that I can run the app on my iPhone from a Windows development machine.

#### Acceptance Criteria

1. THE System source SHALL build and run domain tests and a local preview on Windows, where the local preview is not iPhone validation.
2. THE build pipeline SHALL run on a supported hosted macOS runner using a pinned stable Flutter SDK.
3. THE build pipeline SHALL resolve dependencies, run checks, and build a release for a physical iPhone with code signing disabled.
4. THE build pipeline SHALL package the device application into a Payload/<App>.app structure as an IPA and upload the IPA as a downloadable artifact.
5. THE build pipeline SHALL NOT produce a simulator application as the deliverable, and the deliverable SHALL run independently of a development server.
6. THE System documentation SHALL describe sideloading with Sideloadly using a free Apple account, including the 7-day signing expiry and refresh, device trust, and Developer Mode.
7. THE System SHALL keep Apple credentials local and SHALL NOT place Apple credentials in source, GitHub, or CI secrets.
8. WHERE a package feature requires an entitlement unavailable to a free Apple account, THE System documentation SHALL identify that feature.
9. THE core features SHALL NOT depend on push notifications, iCloud, or background services.

### Requirement 21: Testable Acceptance Examples

**User Story:** As the owner, I want concrete worked examples embedded as acceptance checks, so that correctness is verifiable against known numbers.

#### Acceptance Criteria

1. THE System SHALL compute CFT_Per_Piece for a 2 × 1 in piece at 6 ft as 1 ÷ 12 = 0.0833 (displayed to 4 decimal places as 0.0833).
2. THE System SHALL compute the CFT of one Bunch of 2 × 1 in at 6 ft as 5 ÷ 6 = 0.8333.
3. THE System SHALL compute the CFT of 5 Bunches of 2 × 1 in at 2 ft as 25 ÷ 18 = 1.3889.
4. THE System SHALL compute the CFT of 12 pieces of 3 × 1 in at 8 ft as exactly 2.0000.
5. WHEN 3 Bunches of Mahogany 2 × 1 in at 6 ft are allocated, THE System SHALL report 30 pieces and exactly 2.5 CFT.
6. WHEN a Receipt is interrupted and the application restarts, THE System SHALL recover the active Receipt, and finishing the Receipt SHALL NOT double-add stock.
7. WHEN finalization is repeated for the same order, THE System SHALL produce no duplicate Invoice and no duplicate stock deduction.
8. WHEN 50 pieces are billed at ₹1200 per CFT with No GST, THE System SHALL compute goods of ₹1,666.67 and, with a ₹100 Loading_Charge (because the order is less than 20 CFT), a payable of ₹1,766.67.
9. WHEN a target of 5 CFT of 2 × 1 in at 6 ft is allocated with meet-or-exceed, THE System SHALL allocate exactly 6 Bunches (60 pieces).
10. WHEN a target of 5 CFT of 2 × 1 in at 7 ft is allocated, THE System SHALL compute 5 Bunches as 4.8611 CFT and 6 Bunches as 5.8333 CFT, and with meet-or-exceed SHALL select 6 Bunches.
11. THE System SHALL pass flexible reaper group tests covering abundance, preferred-share shortage, absence of 2 ft stock, and total shortage, each producing whole Bunches, excluding 8 ft and 9 ft, and repeatable to the same result.
12. WHEN a fixed-length Order_Request cannot be met, THE System SHALL NOT silently mix in other lengths.
13. WHEN a flexible Plank Order_Request is allocated, THE System SHALL NOT apply reaper length-group shares.
14. WHEN an Order_Request contains multiple Lines, THE System SHALL NOT reuse the same stock quantity across Lines.
15. IF stock or a Rate is missing for a sold Line, THEN THE System SHALL block finalization.
16. THE System SHALL set the Loading_Charge using exact CFT at the tiers just below 20 CFT (₹100), exactly 20 CFT (₹150, provisional per OD and CD-6), and just above 20 CFT (₹150).
17. THE System SHALL compute tax totals for No GST, literal 9%, and literal 18% consistent with the single-tax-line rule.
18. WHEN goods of ₹1,000 and a ₹100 Loading_Charge are billed at a literal 18% Tax_Rate_Mode with loading untaxed, THE System SHALL compute tax of ₹180 and a payable of ₹1,280.
19. WHEN an undo on a Receipt would make available stock negative, THE System SHALL block the undo.
20. THE System SHALL perform finalization atomically.
21. WHILE an order is in draft, preview, or sharing, THE System SHALL NOT change stock.
22. WHEN a Rate or the Catalog changes, THE System SHALL NOT alter an already-issued Invoice.
23. WHEN a Void is recorded, THE System SHALL restore stock exactly once.
24. THE System SHALL produce a valid Word document whose values match the preview and the WhatsApp text, including multi-page output and verified real-iPhone sharing.
25. WHEN the application is offline and restarted, THE System SHALL preserve calculations, cached browsing results, receiving entries, and drafts without data loss, while finalized billing requires cloud confirmation, and a Backup/restore round-trip SHALL preserve stock balances and Invoice identity without duplication.
26. WHEN a finalize request is lost or duplicated and then retried with the same Idempotency_Key, THE System SHALL produce exactly one Invoice and exactly one stock deduction.
27. WHILE a received quantity remains Pending_Receiving_Stock, THE System SHALL NOT allow it to be sold until synchronization confirms it as Confirmed_Available_Stock.

## Assumptions & Open Decisions Register

This register separates settled decisions from provisional defaults. Confirmed decisions are treated as requirements. Open decisions carry a provisional default so implementation can proceed; they are not confirmed requirements and may change when the owner decides.

### Confirmed Decisions (CD)

- **CD-1 (Sale units):** Reapers are sold and allocated in whole Bunches of 10 only; no loose-piece reaper sales. Planks are counted and sold by whole pieces. (See Requirement 3.)
- **CD-2 (Rate basis):** Selling Rate is ₹ per CFT, GST-exclusive, dependent on Variety and Cross_Section only; length does not change the Rate. (See Requirement 4.)
- **CD-3 (CFT-target allocation):** Target-CFT allocation uses ceil(requested_CFT ÷ CFT_per_sale_unit) with exact arithmetic to meet or exceed the request with the smallest excess; the ceiling applies to unit counts, not money. Always-round-up (meet-or-exceed) is the ONLY target direction; there is no at-most or closest option. (See Requirements 7.6 and 8.2.)
- **CD-4 (Flexible reaper shares):** The 60/30/10 reaper length preferences (6-7 ft = 60%, 3-5 ft = 30%, 2 ft = 10%) are approximate stock-aware shares of allocated CFT, not an exact integer-Bunch guarantee. (See Requirement 8.8.)
- **CD-5 (Tax model):** GST uses a literal total rate mode (No GST, 9% total, 18% total) shown as a single tax line, not a CGST+SGST split. The Loading_Charge is excluded from the taxable base and added after tax; loading still applies in No-GST mode. (See Requirements 10 and 11.)
- **CD-6 (Loading tiers):** Actual total sold CFT less than 20 => ₹100; greater than or equal to 20 (including exactly 20) => ₹150. Applied once per order; never on receiving, empty, or cancelled orders; compared on exact CFT, not display-rounded. (See Requirement 11.)
- **CD-7 (Architecture):** The authoritative store is a hosted managed database (Supabase preferred, Neon allowed), fronted by a local SQLite cache and a durable pending-operation queue. Privileged Hosted_Database access requires an authenticated owner session (Supabase with appropriate Row Level Security and client-safe configuration, or Neon through an authenticated API); no privileged or service-role keys are embedded in the app. Receiving entries save locally and synchronize via idempotency keys, with Pending_Receiving_Stock distinguished from Confirmed_Available_Stock and pending stock not sellable until synced. Finalization requires an authenticated hosted-database transaction with idempotent retry. Calculation, browsing, receiving, and drafts work offline; finalized billing requires cloud confirmation. Still single device and single user. The Windows laptop plus free-account Sideloadly build and sideload path is unchanged. (See Requirements 5, 12, 16, 19, and 20.)
- **CD-8 (Scope):** Plywood is deferred; version 1 handles rectangular timber only. (See Introduction.)

### Open Decisions (OD)

- **OD-1 (Nominal vs actual dimensions):** Are cross-section dimensions nominal trade sizes or actual measured dimensions for billing? **Provisional default:** nominal labels are displayed, and exact integer dimensions are used in the volume formula.
- **OD-2 (Bunch composition):** Can a Bunch be split, are incoming Bunches uniform length, and do mixed-length Bunches exist? **Provisional default:** Bunches are uniform length; if mixed-length Bunches exist, receive their constituent pieces by length.
- **OD-3 (Category mapping):** Is 2 × 1 the only Reaper, with 3 × 1 through 7 × 1 as Planks? **Provisional default:** yes; Category is stored as metadata and is correctable without corrupting history.
- **OD-4 (Plank flexible policy):** Does a flexible-length preference policy apply to Planks? **Provisional default:** no reaper weights on Planks; flexible Plank allocation uses whole pieces, minimizes CFT difference, and applies a deterministic tie-break.
- **OD-5 (8 ft and 9 ft in flexible reaper orders):** How should 8 ft and 9 ft be used in flexible reaper orders? **Provisional default:** excluded unless an enabled fallback policy allows them.
- **OD-6 (Correction model):** Void versus statutory credit-note? **Provisional default:** local Void/reversal only; credit-note is out of scope for v1; a local Void does not fulfil statutory tax correction.
- **OD-7 (CSV import/export):** Should CSV import/export exist for bulk opening stock? **Provisional default:** optional, added after manual receiving works; not a prerequisite.
- **OD-8 (Grand-total rounding):** Should the grand total round to whole rupees? **Provisional default:** no whole-rupee rounding; display paise; if requested later, show a separate round-off line.
- **OD-9 (Tax-invoice statutory fields):** Are the business GST and tax-invoice statutory fields complete? **Provisional default:** produce a simple sales bill unless the owner supplies full statutory details.
