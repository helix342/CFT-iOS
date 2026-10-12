# Wood CFT — On-Device Manual Test Checklist

> **Spec:** Task 17.5 — "Define and perform the on-device manual test checklist"
> **Requirements:** 14.1, 14.5, 14.7, 15.4, 15.5, 17.2, 17.3, 17.4, 17.5, 17.6, 20.5, 20.6, 21.24 (see also 19.11, 21.25)
> **Design:** _Testing Strategy_ → Manual on-device tests
> **Related docs:** [`SIDELOADING.md`](./SIDELOADING.md) (task 16.2) — install/sign/trust/refresh procedure

This checklist is the authoritative **device-only** acceptance gate for Wood CFT.
Every item below must be executed by the owner on a **real iPhone**, against the
**unsigned IPA produced by CI** and sideloaded per [`SIDELOADING.md`](./SIDELOADING.md).

---

## ⛔ Device verification was NOT performed in this environment

**This checklist was authored on a Windows machine with no macOS and no iPhone.**
Nothing here has been executed or verified on real hardware. iOS install, signing,
share-sheet behavior, WhatsApp attachment handling, VoiceOver, dynamic type, and
the ~7-day re-sign cycle **cannot** be reproduced or substituted off-device.

**Every item in this checklist is a PENDING OWNER ACTION.** No item may be marked
`[x]` or reported as "passed" by this build environment, by any automated test, or
by anyone who has not personally observed the result on the physical device.

Rules for using this document:

- Leave each checkbox **unchecked** (`[ ]`) until the step is actually performed on
  the iPhone with the observed result recorded in the **Result / notes** column.
- An automated or off-device test **never** satisfies a device-only item (per
  design _Testing Strategy_: "not satisfied by any off-device test").
- Record the test context (iPhone model, iOS version, app version / CI run,
  Sideloadly version, date, tester) in the run header before starting.
- Any value, label, menu path, or version named below is a **starting point** and
  must be confirmed on the actual device and current OS/app build.

---

## Run header (fill in per test session)

| Field | Value (owner to fill) |
| --- | --- |
| Date performed | _pending_ |
| Tester | _pending_ |
| iPhone model | _pending_ |
| iOS version | _pending_ |
| App version / CI run (`Runner.ipa`) | _pending_ |
| Sideloadly version (or Xcode) | _pending_ |
| Bundle id signed with | _pending_ |
| Overall status | **NOT STARTED — device verification outstanding** |

---

## A. Install, signing, and dev-server-independent launch
_Requirements 20.5, 20.6 — cross-ref [`SIDELOADING.md`](./SIDELOADING.md) §4–§5_

| # | Pending owner action (perform on device) | Expected result | Done | Result / notes |
| --- | --- | --- | --- | --- |
| A1 | Download the CI `Runner-ipa` artifact and extract `Runner.ipa`. | Unsigned IPA with `Payload/Runner.app` present. | [ ] | _pending_ |
| A2 | Sign + install `Runner.ipa` via Sideloadly (free Apple account) per [`SIDELOADING.md`](./SIDELOADING.md). | Install completes; app icon **Wood Cft** appears on the home screen. | [ ] | _pending_ |
| A3 | Trust the developer certificate (Settings → General → VPN & Device Management) and enable Developer Mode if iOS 16+. | App is allowed to launch. | [ ] | _pending_ |
| A4 | Launch **Wood Cft** with **no development server running** and the Mac/PC disconnected. | App launches and is fully usable standalone — proves the deliverable runs independent of a dev server (20.5). | [ ] | _pending_ |
| A5 | Confirm the four bottom tabs (Stock, Sell, Bills, Settings) load and are navigable. | Native Cupertino shell renders; no crash. | [ ] | _pending_ |

## B. First-run setup
_Requirements 17.12, 1.1, 1.2, 1.12 (first-run config, seeded catalog, zero stock, no seeded prices) — design "First-run setup"_

| # | Pending owner action (perform on device) | Expected result | Done | Result / notes |
| --- | --- | --- | --- | --- |
| B1 | On a clean install, complete first-run setup. | App requests **only** the minimum configuration needed to begin. | [ ] | _pending_ |
| B2 | Open the Stock tab and inspect the catalog. | Varieties **Mahogany, Kalani, Palajathi** and cross-sections **2×1 Reaper, 3×1, 4×1, 5×1, 6×1, 7×1 Plank** are present. | [ ] | _pending_ |
| B3 | Inspect stock balances and the price matrix (Settings). | Every item quantity is **zero**; **no prices seeded**; no fictional stock. | [ ] | _pending_ |

## C. Receiving entry and resume-after-restart
_Requirements 19.7, 19.8, 5.7, 20.6, 21.6, 21.27 — offline immediate commit + pending-not-sellable + interrupted-receipt recovery_

| # | Pending owner action (perform on device) | Expected result | Done | Result / notes |
| --- | --- | --- | --- | --- |
| C1 | Start a receiving session; enter quantities across lengths (reaper in bunches, planks in pieces). | Entry saved to the local cache immediately; received quantity shows as **Pending** (not yet sellable). | [ ] | _pending_ |
| C2 | **Force-quit the app mid-session** (interrupt the receipt), then relaunch. | The active receipt and its entries are **recovered** — nothing lost. | [ ] | _pending_ |
| C3 | Finish the recovered receipt. | Stock is **not double-added** (21.6); totals match what was entered once. | [ ] | _pending_ |
| C4 | Attempt to sell the pending-received quantity before sync confirms it. | Selling is **blocked** for pending stock until synchronization confirms it as available (21.27). | [ ] | _pending_ |

## D. Offline browsing and drafts
_Requirement 19.11, 21.25 (offline durability across restart) — everyday work is offline-capable_

| # | Pending owner action (perform on device) | Expected result | Done | Result / notes |
| --- | --- | --- | --- | --- |
| D1 | Enable Airplane Mode. Browse and filter inventory; use calculate-only. | Cached browsing, filtering, and CFT calculation all work offline. | [ ] | _pending_ |
| D2 | While offline, create a draft order (any of the four request types) and a receiving entry. | Draft and receiving entry are created and persisted locally. | [ ] | _pending_ |
| D3 | Force-quit and relaunch while still offline. | Calculations, cached browsing results, receiving entries, and drafts are **preserved without data loss** (21.25). | [ ] | _pending_ |

## E. Finalization requires connectivity + authenticated session
_Requirements 19.3, 19.11, 12.* (finalized billing requires cloud confirmation)_

| # | Pending owner action (perform on device) | Expected result | Done | Result / notes |
| --- | --- | --- | --- | --- |
| E1 | While **offline** (or signed out), attempt to **finalize** a bill. | Finalize is **not allowed** — it requires connectivity and an authenticated session; no invoice number is consumed. | [ ] | _pending_ |
| E2 | Go online, **sign in** (authenticated owner session), and finalize the same order. | Finalize succeeds exactly once; stock deducts once; invoice gets a number. | [ ] | _pending_ |
| E3 | Confirm the draft/preview did not change stock before finalize. | Stock unchanged during draft/preview/sharing (21.21). | [ ] | _pending_ |

## F. Invoice DOCX export, share sheet, Word, and WhatsApp
_Requirements 14.1, 14.5, 14.7, 21.24 — editable Word doc, multi-page header repetition, iOS share sheet, verified WhatsApp attachment — design "DOCX attachment sharing"_

| # | Pending owner action (perform on device) | Expected result | Done | Result / notes |
| --- | --- | --- | --- | --- |
| F1 | From a real finalized invoice, export the **`.docx`** Word document. | A valid OOXML `.docx` is produced with a human-readable filename (not a renamed text/HTML/PDF). | [ ] | _pending_ |
| F2 | Open the exported `.docx` in **Microsoft Word** (or Pages) on the device. | File opens as an **editable Word document**; values match the on-screen preview exactly. | [ ] | _pending_ |
| F3 | Export/finalize an invoice long enough to **span multiple pages**; open it. | The **business header repeats on each page** (14.5). | [ ] | _pending_ |
| F4 | Share the `.docx` through the **iOS share sheet** and attach it in **WhatsApp**. | Share sheet offers the file; WhatsApp **accepts and attaches** the `.docx` to a chat (21.24). | [ ] | _pending_ |
| F5 | Confirm export to the **Files app** also works. | `.docx` saved to Files and reopens correctly. | [ ] | _pending_ |

## G. WhatsApp text share / copy and generic fallback
_Requirements 15.4, 15.5 — Share invoice file / Share bill text / Copy bill text, plus generic share-sheet fallback_

| # | Pending owner action (perform on device) | Expected result | Done | Result / notes |
| --- | --- | --- | --- | --- |
| G1 | Use **Share bill text** to WhatsApp. | Formatted, readable bill text is shared; values match the preview; no Markdown tables. | [ ] | _pending_ |
| G2 | Use **Copy bill text** and paste into a chat/note. | Text copies to clipboard and pastes intact. | [ ] | _pending_ |
| G3 | Use **Share invoice file** action. | File share action works as expected. | [ ] | _pending_ |
| G4 | On a device **without WhatsApp installed** (or disabled), trigger a share. | The **generic iOS share sheet** is offered as the fallback (15.5). | [ ] | _pending_ |

## H. Accessibility
_Requirements 17.2, 17.3, 17.4, 17.5, 17.6 — SF Symbols bridge + fallback, 44×44 pt targets, dynamic type, VoiceOver, non-color shortage, unit labels_

| # | Pending owner action (perform on device) | Expected result | Done | Result / notes |
| --- | --- | --- | --- | --- |
| H1 | Turn on **VoiceOver**; navigate inventory and an invoice preview. | VoiceOver reads **quantity and CFT with explicit unit labels** (17.4, 17.6). | [ ] | _pending_ |
| H2 | Increase **Dynamic Type** to a large accessibility size. | Text **scales** without clipping or broken layout (17.4). | [ ] | _pending_ |
| H3 | Check interactive controls (buttons, tab bar, grid cells). | Touch targets are at least **44 × 44 pt** (17.3). | [ ] | _pending_ |
| H4 | View an item in a **shortage** state. | Shortage is conveyed by a **non-color indicator** (icon/text), not color alone (17.5). | [ ] | _pending_ |
| H5 | Observe icons across screens and record the SF Symbols bridge outcome. | SF Symbols render via the supported bridge; **Cupertino fallback** is used where unavailable — **record availability and the fallback used** (17.2). | [ ] | _pending_ |

## I. Backup / restore round-trip and ~7-day re-sign survival
_Requirements 16.* (16.2 backup-before-reinstall, 16.5 no duplicate movement), 21.25 — plus the free-account ~7-day re-sign cycle (20.6, design "7-day signing expiry")_

| # | Pending owner action (perform on device) | Expected result | Done | Result / notes |
| --- | --- | --- | --- | --- |
| I1 | With real data present, run the in-app **Backup** action. | A portable backup (catalog, stock ledger, receipts, invoices, settings) is produced. | [ ] | _pending_ |
| I2 | Perform a **Restore** from that backup (restoring validates schema + version). | Restore validates schema/version; **stock balances and invoice identity are preserved** with **no duplicated stock movement** (16.5, 21.25). | [ ] | _pending_ |
| I3 | Note the install date and let the free-account signature approach the **~7-day** expiry; **re-sign** with the **same bundle id** per [`SIDELOADING.md`](./SIDELOADING.md) §5. | App reinstalls over the existing install; **on-device data survives** the re-sign. | [ ] | _pending_ |
| I4 | After re-sign, relaunch and verify data integrity (stock, receipts, finalized invoices). | All data intact and consistent after the re-sign cycle. | [ ] | _pending_ |
| I5 | (Optional) Sign back in online after a reinstall. | Hosted authoritative store reconciles; finalized data recoverable. | [ ] | _pending_ |

---

## Sign-off

Device verification is complete **only** when every box above is checked with an
observed result recorded, and the run header is filled in.

| | |
| --- | --- |
| All items performed on real hardware | **NO — pending owner action** |
| Tester signature | _pending_ |
| Date | _pending_ |

> Until this sign-off is completed on a physical iPhone, the on-device acceptance
> for task 17.5 remains **unsatisfied** and MUST NOT be reported as passing.
