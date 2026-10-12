# Wood CFT — Property-Based Suite Manifest

This document records the full property-based test suite for the Wood CFT app.
Each of the design's **Correctness Properties 1–31** (`.kiro/specs/wood-cft-app/design.md`
→ *Correctness Properties*) is implemented by at least one property-based test
tagged in the canonical form:

```
Feature: wood-cft-app, Property {N}: {text}
```

Coverage is enforced automatically by
[`test/property_suite_manifest_test.dart`](../test/property_suite_manifest_test.dart),
which scans the whole `test/` tree, extracts every property tag, and fails if
any design property (1–31) is missing a tagged test. Run it headless on Windows
with:

```
flutter test test/property_suite_manifest_test.dart
```

The manifest test also prints the live Property → test-file mapping to the test
output, so the table below is the human-readable snapshot and the test is the
source of truth.

## Property → covering test file

| # | Property (short) | Covering test file(s) |
|---|------------------|-----------------------|
| 1 | Exact CFT formula | `test/domain/cft_formula_property_test.dart` |
| 2 | Unit scaling is exact multiplication | `test/domain/cft_formula_property_test.dart` |
| 3 | Total CFT is the exact order-independent sum | `test/application/total_cft_order_independent_property_test.dart` |
| 4 | Display rounding never alters computation | `test/domain/cft_money_property_test.dart` |
| 5 | Whole-unit invariant for sale quantities | `test/application/whole_unit_invariant_property_test.dart` |
| 6 | Meet-or-exceed single-SKU unit count | `test/application/allocation_meet_or_exceed_property_test.dart` |
| 7 | Hard constraints are never violated | `test/application/allocation_hard_constraints_honesty_property_test.dart` |
| 8 | Allocation honesty (no silent reduction) | `test/application/allocation_hard_constraints_honesty_property_test.dart` |
| 9 | Billing uses actual allocated CFT | `test/application/billing_allocated_cft_no_double_count_property_test.dart` |
| 10 | Multi-line allocation never double-counts | `test/application/allocation_multiline_property_test.dart`, `test/application/billing_allocated_cft_no_double_count_property_test.dart` |
| 11 | Deterministic with a stable tie-breaker | `test/application/allocation_determinism_exclusion_property_test.dart` |
| 12 | Flexible reaper excludes 8–9 ft; no reaper weights on planks | `test/application/allocation_flexible_reaper_property_test.dart`, `test/application/allocation_determinism_exclusion_property_test.dart` |
| 13 | Flexible plank: whole pieces, minimal excess | `test/application/allocation_flexible_plank_property_test.dart` |
| 14 | Line amount exact before half-up; goods subtotal sums rounded lines | `test/application/billing_properties_test.dart`, `test/application/billing_goods_subtotal_property_test.dart`, `test/domain/cft_money_property_test.dart` |
| 15 | Single-line literal tax on taxable subtotal | `test/application/billing_tax_property_test.dart`, `test/application/billing_properties_test.dart` |
| 16 | Loading excluded from tax, added once after tax | `test/application/billing_loading_property_test.dart`, `test/application/billing_loading_exclusion_tier_property_test.dart` |
| 17 | Loading tier is a step function on exact CFT at 20 | `test/application/billing_loading_property_test.dart`, `test/application/billing_loading_exclusion_tier_property_test.dart` |
| 18 | Non-finalizing actions never mutate stock | `test/application/non_finalizing_actions_no_stock_mutation_property_test.dart` |
| 19 | Idempotent operation application | `test/data/hosted_idempotent_apply_property_test.dart` |
| 20 | Negative-availability adjustments rejected | `test/application/negative_availability_rejection_property_test.dart` |
| 21 | Only confirmed stock is sellable | `test/application/pending_vs_confirmed_sellability_property_test.dart` |
| 22 | Balance reconciles with the movement ledger | `test/data/stock_ledger_dao_test.dart` |
| 23 | Inventory totals equal the sum over the active filter | `test/application/inventory_totals_filter_property_test.dart` |
| 24 | Finalized invoice snapshots are immutable | `test/application/finalize_snapshot_void_missing_rate_property_test.dart` |
| 25 | Void restores exactly the deducted stock | `test/application/finalize_snapshot_void_missing_rate_property_test.dart` |
| 26 | Missing rate blocks finalization | `test/application/finalize_snapshot_void_missing_rate_property_test.dart` |
| 27 | Export outputs are consistent with the snapshot | `test/application/export_consistency_ooxml_property_test.dart` |
| 28 | Exported DOCX is a valid OOXML package | `test/application/export_consistency_ooxml_property_test.dart` |
| 29 | Backup/restore round-trip preserves data | `test/data/backup_service_test.dart` |
| 30 | Offline durability across restart | `test/data/offline_durability_property_test.dart` |
| 31 | Incomplete statutory fields prevent a verified tax invoice | `test/domain/statutory_fields_presentation_property_test.dart` |

## Notes

- The design specifies **one** property test per property. A few properties
  carry an extra focused variant in this codebase (e.g. 5, 10, 12, 14, 15, 16,
  17). The manifest test reports over-coverage for information but does not fail
  on it; it fails only when a property has **no** tagged test.
- Properties 30 and 31 were added by task 17.1
  (`offline_durability_property_test.dart` and
  `statutory_fields_presentation_property_test.dart`) to complete the 1–31 set.
- Every property test runs ≥100 iterations via `package:glados`
  (`ExploreConfig(numRuns: …)`), seeded deterministically so counterexamples
  reproduce.
