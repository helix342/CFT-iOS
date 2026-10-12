# Sideloading Wood CFT onto an iPhone (free Apple account)

> **Spec:** Task 16.2 — "Write sideload + entitlement documentation"
> **Requirements:** 20.1, 20.6, 20.8, 20.9 (see also 20.5, 20.7)
> **Design:** _Windows-to-iPhone Build Path_ → Sideloading / Free-account entitlement constraints

This guide explains how the owner installs the **unsigned IPA** produced by CI
onto a **single iPhone** using a **free Apple account** (no paid Apple Developer
Program membership). It covers free-provisioning ("personal team") 7-day
signing, device trust, Developer Mode, the app's bundle identifier, and the
required entitlements.

---

## ⚠️ On-device verification was NOT performed in this environment

**This document was authored on a Windows machine with no macOS and no iPhone
available.** None of the steps below have been executed or verified on real
hardware here. iOS signing and installation require macOS/Xcode and/or a
Windows sideloading tool plus a physical device.

**The owner MUST perform the actual install and app-launch verification on a
Mac and/or on the iPhone.** Until that is done on real hardware, the sideload
and on-device launch MUST NOT be reported as passing. The matching
device-only checklist lives in task 17.5.

Any command, path, UI label, or version named below is a **starting point** and
**must be confirmed** against the current Sideloadly release, the installed iOS
version, and the toolchain that actually produced the IPA.

---

## 1. What you are installing

The CI workflow `build-ios-ipa` (`.github/workflows/ios-build.yml`, task 16.1)
builds a **release, device (`iphoneos`), code-signing-disabled** build and
packages it as an **unsigned** `.ipa`:

- Workflow artifact name: **`Runner-ipa`**
- File inside the artifact: **`Runner.ipa`**
- IPA layout: `Payload/Runner.app`

"Unsigned" means the IPA carries **no code signature and no provisioning
profile**. The signature is applied **locally, by you**, during sideloading —
never in CI. This is deliberate so that **no Apple credentials are ever stored
in source, GitHub, or CI secrets** (Requirement 20.7).

### App identity (confirm before signing)

| Field | Value |
| --- | --- |
| Bundle identifier (`PRODUCT_BUNDLE_IDENTIFIER`) | `com.woodcft.woodCft` |
| Display name (`CFBundleDisplayName`) | `Wood Cft` |
| Internal name (`CFBundleName`) | `wood_cft` |

See `ios/Runner.xcodeproj/project.pbxproj` and `ios/Runner/Info.plist`.

---

## 2. Prerequisites

- A **free Apple account** (any Apple ID works; a paid membership is not
  required). Keep these credentials **local only**.
- The **`Runner.ipa`** file downloaded from the CI run's `Runner-ipa` artifact.
- A **single iPhone** with a Lightning/USB-C cable.
- A signing tool. Choose **one** path:
  - **Windows path:** [Sideloadly](https://sideloadly.io/) + iTunes/Apple
    Devices drivers (so the PC can see the iPhone).
  - **macOS path:** Xcode with a **free personal team** (see §6).

> Apple account email, password, and any app-specific password stay on your
> machine. Do not paste them into source, commit messages, GitHub, or CI
> secrets (Requirement 20.7).

---

## 3. Bundle identifier and free-provisioning ("personal team")

A **free Apple account** signs apps with a **personal team** using
**free provisioning**. Two consequences matter:

1. **Signing lasts ~7 days.** A personal-team signature expires after about a
   week, after which the app will refuse to launch until you **re-sign**
   (see §5).
2. **The bundle identifier may need to be unique to your account.** Free
   provisioning sometimes rejects a bundle id that another developer has
   already registered. If signing fails with a "cannot register bundle
   identifier" / "identifier is not available" error, change it to something
   unique for your Apple ID, for example:

   ```text
   com.<your-name>.woodcft
   ```

   - In **Sideloadly**, set the **Bundle ID** field before installing.
   - In **Xcode**, change **Signing & Capabilities → Bundle Identifier**.

   Changing the bundle id makes iOS treat it as a different app, so a prior
   install under the old id will not be upgraded in place. Back up first
   (see §8).

---

## 4. Install with Sideloadly (Windows path)

1. Install **iTunes** (or Apple Devices) so Windows recognizes the iPhone, then
   install **Sideloadly**.
2. Connect the iPhone by cable and tap **Trust This Computer** on the phone if
   prompted.
3. Open **Sideloadly**:
   - Select the connected iPhone as the target device.
   - Drag **`Runner.ipa`** into the IPA/app field.
   - Enter your **free Apple ID**. If two-factor is on, generate and use an
     **app-specific password** from your Apple account.
   - (If needed) set a unique **Bundle ID** per §3.
4. Click **Start**. Sideloadly signs the IPA with your personal team and
   installs it.
5. **Trust the developer certificate on the device** (see §5), enable
   **Developer Mode** if iOS asks (see §5), then launch **Wood Cft**.

> If Sideloadly reports a signing/registration error, it is almost always the
> **bundle id** (§3) or a **two-factor password** issue — not a problem with the
> IPA itself.

---

## 5. Device trust, Developer Mode, and the 7-day refresh

### Trust the developer certificate

After the first install, iOS treats a personal-team certificate as untrusted
until you approve it:

**Settings → General → VPN & Device Management** → select your Apple ID / the
developer app → **Trust**.

(The exact menu wording varies by iOS version — confirm on the device.)

### Enable Developer Mode (iOS 16 and later)

Recent iOS versions require Developer Mode to run sideloaded apps:

**Settings → Privacy & Security → Developer Mode** → turn **On** → the device
restarts → confirm after reboot.

(Only present on iOS 16+. On older iOS, trusting the certificate above is
sufficient.)

### The ~7-day signing expiry and refresh

A free personal-team signature is valid for **about 7 days**. When it expires,
the app stops launching (iOS reports it can no longer be verified). To refresh:

- **Re-sign** by re-running the same Sideloadly install with the **same bundle
  id** before (or just after) expiry, **or**
- In Xcode, build/run to the device again.

Re-signing with the same bundle id reinstalls over the existing app and
**preserves on-device data**. The app is designed to survive reinstall without
data loss (local cache + hosted authoritative store + backup/restore). As a
safety net, take a backup before any re-sign where you change the bundle id or
are unsure (see §8).

> **Reminder:** budget a quick re-sign roughly once a week. This is a free-
> account limitation, not an app bug.

---

## 6. macOS / Xcode path (alternative to Sideloadly)

If you have access to a Mac, you can install using Xcode and a free personal
team instead of Sideloadly:

1. Open the project in Xcode (`ios/Runner.xcworkspace`).
2. **Signing & Capabilities** for the **Runner** target:
   - **Team:** select your personal (free) team — "Add an Account…" with your
     Apple ID if none is listed.
   - Enable **Automatically manage signing**.
   - Set a **unique Bundle Identifier** if the default
     `com.woodcft.woodCft` is rejected (see §3).
3. Connect and select the iPhone as the run destination.
4. **Product → Run** (or build an unsigned device build via CI and let Xcode
   sign it on install).
5. Trust the certificate and enable Developer Mode on the device exactly as in
   §5. The same **~7-day expiry** applies.

> The CI build itself is **unsigned on purpose** — do not add signing or Apple
> credentials to the CI workflow. Signing is always a **local** step.

---

## 7. Entitlements and free-account constraints (Requirements 20.8, 20.9)

A **free Apple account cannot grant** these capabilities:

- **Push notifications**
- **iCloud** (CloudKit / key-value / iCloud documents)
- **Background execution** services (background fetch, background processing,
  background push, etc.)
- Associated domains, HealthKit, HomeKit, and similar managed entitlements.

It also enforces practical limits: **~7-day resign cycle**, a small cap on the
number of sideloaded apps, and a limited number of registered devices per Apple
ID.

### Wood CFT's required entitlements

**Wood CFT's core features require none of the restricted entitlements.** The
app is designed to work within a free account:

- **Inventory, CFT calculation, catalog browsing, receiving entry, drafts,
  settings** run **locally** against the SQLite cache and durable pending-op
  queue — no push, no iCloud, no background services.
- **Export** (editable Word `.docx`) and **WhatsApp / share-sheet sharing** are
  **user-initiated** foreground actions — no background services or special
  entitlement.
- **Hosted-database access** (Supabase/Neon) uses **plain HTTPS**, which needs
  **no special entitlement** on a free account. Finalized billing requires
  connectivity by design, but that is ordinary network access, not a managed
  capability.

### Features flagged as needing an unavailable entitlement

**None at this time.** No core feature depends on push notifications, iCloud, or
background services (Requirement 20.9), so **no entitlement unavailable to a
free account is required** to run Wood CFT.

> **If this ever changes:** should a future dependency pull in a plugin that
> requests push, iCloud, or a background mode, that feature **must be listed
> here** and either removed from core or gated so the free-account build still
> works (Requirement 20.8). Review `ios/Runner/Runner.entitlements` (if present)
> and each plugin's iOS requirements whenever dependencies change.

---

## 8. Back up before re-sign / reinstall

Because the free-account workflow involves periodic re-signing (and sometimes a
bundle-id change), take a backup before anything that could reset app storage:

- Use the app's **in-app backup/restore** (export catalog, stock ledger,
  receipts, invoices, settings) before a bundle-id change or a reinstall you are
  unsure about.
- The hosted database remains the authoritative store, so finalized data is
  recoverable after a reinstall once you sign back in.

A same-bundle-id re-sign normally preserves local data; a bundle-id change
starts a fresh install, so restore from backup afterward.

---

## 9. Credential hygiene (Requirement 20.7)

- Keep the **Apple ID and app-specific password local**. Never commit them,
  never put them in GitHub, never add them to CI secrets.
- The CI workflow intentionally references **no secrets** and needs none.
- Hosted-DB credentials are likewise **not** build-time secrets.

---

## 10. Quick checklist (perform on real hardware)

> These are **device-only** steps. They are **not** satisfied by anything in
> this repository and were **not** executed in the authoring environment.

- [ ] Download the `Runner-ipa` artifact and extract `Runner.ipa`.
- [ ] Confirm/choose a unique bundle id for your Apple ID (§3).
- [ ] Sign + install via Sideloadly (Windows) or Xcode (macOS).
- [ ] Trust the developer certificate on the device (§5).
- [ ] Enable Developer Mode if on iOS 16+ (§5).
- [ ] Launch **Wood Cft** and confirm it runs **independent of a dev server**
      (Requirement 20.5).
- [ ] Note the install date; plan to **re-sign within ~7 days** (§5).

See task 17.5 for the full must-actually-perform on-device checklist.
