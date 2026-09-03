# InkSync — Complete Project Handover

> **Last updated:** June 30, 2026
> **Repository:** https://github.com/livetaub/InkSync---Flutter
> **Live App:** https://app.inksyncnote.com
> **Marketing Site:** https://inksyncnote.com
> **Play Store:** https://play.google.com/store/apps/details?id=com.InkSync

---

## 1. Project Overview

InkSync is a **cross-platform note-taking app** focused on simplicity, real-time collaboration, and seamless sync. It runs on Android, iOS, and Web.

| Field | Value |
|---|---|
| **App Version** | 1.0.3+4 (pubspec) / 2.0.0 (AppConfig) |
| **Package ID** | `com.InkSync` (Android) / `com.inksync.inksync` (namespace) |
| **Framework** | Flutter 3.38+ / Dart SDK ^3.10.4 |
| **State Management** | Provider |
| **Backend** | Supabase (PostgreSQL + Edge Functions + Auth) |
| **Payments** | Stripe (web/Android) + RevenueCat (iOS — not yet configured) |
| **AI** | Google Gemini 2.5 Flash (via Supabase Edge Function proxy) |
| **Email** | Resend API (via Supabase DB triggers + vault secrets) |
| **Hosting** | Cloudflare Pages (3 projects) |
| **CI/CD** | GitHub Actions (2 Android build workflows) |
| **Support** | HelpLoop SDK (in-app messaging) |
| **Deep Link Scheme** | `io.supabase.inksync` |

---

## 2. Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                         INKSYNC ARCHITECTURE                         │
├──────────────┬───────────────────────────────────────────────────────┤
│ Clients      │ Flutter (Android/iOS/Web) + React marketing site     │
│ Backend      │ Supabase (PostgreSQL + Edge Functions + Auth + RLS)   │
│ Payments     │ Stripe (web/Android checkout) + RevenueCat (iOS)      │
│ AI           │ Google Gemini 2.5 Flash (via Edge Function proxy)     │
│ Email        │ Resend API (via DB triggers + vault secrets)          │
│ Hosting      │ Cloudflare Pages (3 projects)                         │
│ CI/CD        │ GitHub Actions (APK + AAB builds)                     │
│ Mobile Store │ SQLite (offline-first) + SyncEngine → Supabase        │
│ Support      │ HelpLoop SDK (in-app chat)                            │
├──────────────┴───────────────────────────────────────────────────────┤
│                                                                      │
│  User → Flutter App → Supabase Auth (email/Google)                   │
│                     → Supabase DB (notes, profiles, collaboration)   │
│                     → Edge Functions (Stripe, Gemini, webhooks)      │
│                     → SQLite (offline cache, mobile only)            │
│                     → HelpLoop (support inbox)                       │
│                                                                      │
│  Admin → Admin Portal (Flutter Web) → Supabase DB (admin_users)      │
│  Marketing → React/Vite site → Cloudflare Pages                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Domain & Hosting Map

| Domain | Cloudflare Project | Content |
|---|---|---|
| `inksyncnote.com` | `inksync-marketing` | React/Vite marketing site |
| `app.inksyncnote.com` | `inksync` | Flutter web app (main product) |
| Admin (Cloudflare URL) | `inksync-admin` | Flutter web admin portal |
| `invite.inksyncnote.com` | — | Email sender domain (Resend) |

---

## 4. File Structure

```
InkSync/
├── .env                            # CLOUDFLARE_API_TOKEN (deploy only)
├── .github/workflows/
│   ├── android_build.yml           # APK build (auto on [build] commits)
│   └── android_build_aab.yml       # AAB build (manual dispatch only)
│
├── lib/                            # ═══ MAIN FLUTTER APP ═══
│   ├── main.dart                   # Entry point, routing, provider setup
│   ├── firebase_options.dart       # Legacy Firebase config (still referenced)
│   │
│   ├── config/
│   │   ├── app_config.dart         # App name/version, Firebase keys
│   │   ├── supabase_config.dart    # Supabase URL + anon key + OAuth client IDs
│   │   ├── stripe_config.dart      # Stripe publishable key + checkout URLs
│   │   └── theme.dart              # AppTheme (light + dark mode)
│   │
│   ├── models/
│   │   └── paywall_variant.dart    # A/B test variant model
│   │
│   ├── providers/
│   │   ├── theme_provider.dart     # ThemeMode (light/dark/system)
│   │   ├── settings_provider.dart  # User settings state
│   │   └── selection_provider.dart # Multi-select state for notes
│   │
│   ├── services/
│   │   ├── auth_service.dart            # Legacy auth wrapper (backward compat)
│   │   ├── supabase_auth_service.dart   # Primary auth service
│   │   ├── notes_service.dart           # Main notes CRUD (25KB)
│   │   ├── supabase_notes_service.dart  # Supabase notes operations
│   │   ├── local_notes_service.dart     # Offline-first local notes
│   │   ├── local_database_service.dart  # SQLite database (21KB)
│   │   ├── sync_engine.dart             # Local ↔ Supabase sync
│   │   ├── gemini_service.dart          # AI writing tools
│   │   ├── calendar_service.dart        # Calendar events
│   │   ├── notification_service.dart    # Push notifications (mobile)
│   │   ├── settings_service.dart        # Preferences persistence
│   │   ├── paywall_service.dart         # A/B paywall logic (14KB)
│   │   ├── subscription_service.dart    # RevenueCat + Stripe (11KB)
│   │   └── tag_service.dart             # Tags/labels
│   │
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart                    # Login + signup (57KB)
│   │   │   ├── auth_wrapper.dart                    # Auth state gate
│   │   │   ├── welcome_screen.dart                  # Mobile onboarding
│   │   │   └── note_unlock_verification_screen.dart # Note password reset
│   │   ├── home/
│   │   │   └── home_screen.dart                     # Notes list (34KB)
│   │   ├── note_edit/
│   │   │   └── note_edit_screen.dart                # Note editor (218KB ⚠️)
│   │   ├── calendar/
│   │   │   └── calendar_screen.dart
│   │   ├── search/
│   │   │   └── search_screen.dart
│   │   ├── settings/
│   │   │   └── settings_screen.dart
│   │   ├── trash/
│   │   │   └── trash_screen.dart
│   │   ├── subscription/
│   │   │   ├── subscription_screen.dart
│   │   │   └── mobile_paywall_screen.dart           # Paywall UI (33KB)
│   │   ├── checkout/
│   │   │   ├── checkout_entry.dart
│   │   │   ├── checkout_screen.dart                 # Web Stripe checkout
│   │   │   ├── checkout_screen_mobile.dart          # Mobile stub
│   │   │   └── android_checkout_screen.dart         # Android WebView checkout
│   │   ├── navigation/
│   │   │   └── main_navigation.dart                 # Bottom nav / sidebar
│   │   ├── shared/
│   │   │   └── shared_note_screen.dart              # Public shared note
│   │   ├── snapshot/
│   │   │   └── snapshot_viewer_screen.dart           # Snapshot viewer (33KB)
│   │   ├── invites/
│   │   │   └── pending_invites_screen.dart
│   │   ├── tutorial/
│   │   │   └── tutorial_screen.dart
│   │   └── help/
│   │       └── help_screen.dart                     # HelpLoop support
│   │
│   ├── widgets/
│   │   ├── app_drawer.dart, app_header.dart
│   │   ├── note_card.dart
│   │   ├── web_sidebar.dart, mobile_sidebar.dart
│   │   ├── main_menu_sheet.dart
│   │   ├── auth_dialogs.dart, login_prompt_modal.dart
│   │   └── invite_banner.dart
│   │
│   └── utils/
│       ├── platform_helper.dart, mobile_helper.dart
│       ├── web_helper.dart, ui_helper.dart
│
├── admin_portal/               # ═══ ADMIN DASHBOARD (Flutter Web) ═══
│   ├── lib/
│   │   ├── main.dart
│   │   ├── theme.dart
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── users_screen.dart
│   │   │   ├── reports_screen.dart
│   │   │   ├── pricing_screen.dart
│   │   │   ├── paywall_screen.dart
│   │   │   └── paywall_editor_screen.dart
│   │   └── widgets/
│   │       ├── admin_scaffold.dart      # Sidebar with Support Inbox link
│   │       └── paywall_preview_widget.dart
│   └── pubspec.yaml            # go_router, fl_chart, supabase_flutter
│
├── marketing/                  # ═══ MARKETING SITE (React/Vite) ═══
│   ├── src/
│   │   ├── main.tsx, App.tsx, App.css, index.css
│   │   ├── components/Navbar.tsx
│   │   ├── pages/
│   │   │   ├── LandingPage.tsx / .css
│   │   │   ├── TermsPage.tsx / .css
│   │   │   └── NotFoundPage.tsx / .css
│   │   └── hooks/useDocumentMetadata.ts
│   └── package.json            # React 19, react-router-dom 7, lucide-react
│
├── supabase/                   # ═══ SUPABASE CONFIG ═══
│   ├── config.toml             # Minimal (only stripe-webhook JWT disabled)
│   ├── functions/
│   │   ├── create-checkout/          # Legacy web checkout
│   │   ├── create-checkout-session/  # Mobile/Android checkout
│   │   ├── create-portal-session/    # Stripe billing portal
│   │   ├── create-subscription/      # Inline card payment
│   │   ├── gemini-proxy/             # AI writing proxy → Gemini 2.5 Flash
│   │   └── stripe-webhook/           # Stripe event handler
│   └── migrations/             # 15 SQL migration files
│
├── supporthub-sdks/            # ═══ HELPLOOP SDK (local dependency) ═══
│   └── flutter/
│       ├── lib/supporthub_sdk.dart    # Barrel file
│       └── lib/src/                   # api/, models/, screens/, widgets/
│
├── android/                    # Android platform files
│   ├── app/build.gradle.kts    # compileSdk 36, minSdk 26, Java 17
│   └── key.properties          # Signing config (plain-text ⚠️)
│
├── deploy_web_app.bat          # Deploy Flutter web → Cloudflare
├── deploy_admin.bat            # Deploy admin portal → Cloudflare
├── deploy_marketing.bat        # Deploy marketing → Cloudflare
└── pubspec.yaml                # All Flutter dependencies
```

---

## 5. Routing (Main App)

Navigation uses `MaterialApp.onGenerateRoute` (NOT GoRouter):

| Route | Screen | Notes |
|---|---|---|
| `/`, `/login` | `LoginScreen` | |
| `/register` | `LoginScreen` | |
| `/app`, `/home` | `AuthWrapper` → `MainNavigation` | Auth-gated |
| `/shared/:token` | `SharedNoteScreen` | Public read-only note |
| `/snapshot/:token` | `SnapshotViewerScreen` | Note snapshot |
| `/checkout?plan=&period=` | `CheckoutScreen` | Stripe payment |
| `/checkout-success` | `CheckoutSuccessScreen` | Post-payment |
| `/note-unlock?token=&note_id=` | `NoteUnlockVerificationScreen` | Password reset |
| Default | `AuthWrapper` | |

**Initial route:** Web → `/`, Mobile → `/app`

> [!NOTE]
> The admin portal uses **GoRouter** (^17.2.3) separately.

---

## 6. Auth System

Two auth services coexist (legacy migration):

| Service | Purpose | Used by |
|---|---|---|
| `AuthService` | Legacy wrapper around Supabase | Existing screens (backward compat) |
| `SupabaseAuthService` | Primary auth, includes `updateProfile()` | Newer code |

**Supported auth methods:**
- Email/password sign-in and sign-up
- Google Sign-In (native on mobile via `google_sign_in`, OAuth redirect on web)
- Password reset via email

**OAuth configuration:**
| Platform | Client ID |
|---|---|
| Web | `624897890206-vdeq2lo0m7r7ffun4glupnd17p1t0pn1.apps.googleusercontent.com` |
| iOS | `624897890206-6b8sbg21sgro6r7co5ocf02tgsben6hk.apps.googleusercontent.com` |
| Android | Configured via Google Cloud Console (2 OAuth clients — upload key + Play Store app signing key) |

**Deep link:** `io.supabase.inksync://login-callback/`

**Mobile onboarding flow:**
1. `_MobilePhase.loading` → Check SharedPreferences + session
2. `_MobilePhase.welcome` → WelcomeScreen (Google/email/guest)
3. `_MobilePhase.tutorial` → TutorialScreen (6 swipeable pages)
4. `_MobilePhase.app` → MainNavigation

Returning users skip to `app`. `has_seen_onboarding` flag in SharedPreferences.

---

## 7. Database Schema (Supabase PostgreSQL)

### Core Tables

**`notes`** (main data):
| Field | Type | Notes |
|---|---|---|
| id | UUID PK | |
| title | TEXT | |
| content | TEXT | |
| type | TEXT | `'text'` or `'checklist'` |
| checklist_items | JSONB | `[{id, text, checked}]` |
| color | TEXT | yellow/orange/red/pink/purple/blue/teal/green |
| is_pinned | BOOL | |
| is_pinned_to_notifications | BOOL | |
| is_locked | BOOL | |
| lock_password | TEXT | |
| trashed_at | TIMESTAMPTZ | Soft delete (auto-purge after 30 days) |
| reminder_at | TIMESTAMPTZ | |
| collaborators | JSONB | `[{email, accepted, canEdit}]` |
| tags | TEXT[] | |
| title_set_manually | BOOL | |
| user_id | UUID FK | |
| created_at, updated_at | TIMESTAMPTZ | |

**`profiles`**:
| Field | Type |
|---|---|
| account_type | TEXT (free/premium) |
| stripe_customer_id | TEXT |
| subscription_id | TEXT |
| subscription_status | TEXT |
| subscription_period_end | TIMESTAMPTZ |
| subscription_origin | TEXT (stripe/revenuecat) |
| ai_credits_used | INT |
| ai_input_tokens | BIGINT |
| ai_output_tokens | BIGINT |

**`collaboration_invites`**:
- Unique on `(note_id, to_email)`
- Status: pending/accepted/rejected
- DB trigger sends HTML email via Resend API on INSERT/UPDATE

**`note_snapshots`** (public sharing):
- Token-based access (UUID token is the security key)
- Content hash dedup prevents duplicate snapshots

**`note_reset_tokens`** (note lock password reset):
- 3 RPC functions: `request_note_unlock`, `check_note_unlock_token`, `verify_note_unlock`
- Tokens expire in 1 hour

### Paywall System (A/B Testing)

**`paywall_variants`** — Test configurations:
- Variant name, traffic weight, is_active
- Free/Premium/Pro tier pricing, note limits, AI credits
- Page headline, subheadline, features (JSONB), CTA text

**`paywall_assignments`** — Sticky user assignments:
- `user_id` → `variant_id` (persisted once assigned)

**`paywall_events`** — Analytics:
- Event types: `paywall_viewed`, `paywall_dismissed`, `cta_clicked`, `checkout_started`, `checkout_completed`, `subscription_active`

**`pricing_config`** — Stripe pricing:
- `premium_monthly` = $7.00, `premium_yearly` = $70.00

**`admin_users`** — Admin access control

---

## 8. Supabase Edge Functions

| Function | JWT | Purpose |
|---|---|---|
| `create-checkout` | Yes | Legacy web checkout → Stripe Checkout Session |
| `create-checkout-session` | Yes | Mobile checkout → reads `paywall_variants` → Stripe hosted URL |
| `create-portal-session` | Yes | Stripe Billing Portal for subscription management |
| `create-subscription` | Yes | Inline card payment → creates Stripe Customer + Subscription |
| `gemini-proxy` | Yes | AI writing proxy → Gemini 2.5 Flash, tracks token usage |
| `stripe-webhook` | **No** | Handles Stripe events (checkout, subscription, invoice) |

**CORS Origin:** `https://app.inksyncnote.com`

**Stripe Webhook Events Handled:**
- `checkout.session.completed` → Activate subscription
- `customer.subscription.updated` → Update status/renewal
- `customer.subscription.deleted` → Downgrade to free
- `invoice.payment_failed` → Mark `past_due`

**Gemini Proxy:**
- Tones: proofread, rephrase, emojify, elaborate, shorten, custom
- Tracks `ai_credits_used`, `ai_input_tokens`, `ai_output_tokens` in profiles
- API key from Supabase vault (`vault.decrypted_secrets`) with env var fallback

---

## 9. Offline-First Architecture (Mobile)

```
User Action → LocalNotesService (SQLite) → SyncEngine → Supabase
```

- **Mobile:** All CRUD goes through `LocalNotesService` (SQLite), then `SyncEngine` syncs in background
- **Web:** Direct Supabase queries (no local DB)
- SQLite tables mirror Supabase schema
- `sync_meta` table stores paywall variant cache, plan limits, etc.
- Conflict resolution handled by SyncEngine

---

## 10. Payment System

### Stripe (Web + Android)

| Config | Value |
|---|---|
| Publishable Key | `pk_live_51SlzeN3vVetXJOaZ...` (LIVE) |
| Checkout Success URL | `https://app.inksyncnote.com/checkout-success` |
| Cancel URL | `https://inksyncnote.com/pricing` |

**Web flow:** CheckoutScreen → Edge Function `create-subscription` → Stripe inline payment
**Android flow:** AndroidCheckoutScreen (WebView) → Edge Function `create-checkout-session` → Stripe hosted checkout

### RevenueCat (iOS)

> [!WARNING]
> RevenueCat is **NOT YET CONFIGURED**. API keys are placeholder values:
> - Apple: `appl_REPLACE_WITH_YOUR_KEY`
> - Google: `goog_REPLACE_WITH_YOUR_KEY`

Entitlement: `premium`

### Plan Limits (Defaults)

| Plan | Notes Limit | AI Credits | Monthly | Yearly |
|---|---|---|---|---|
| Free | 75 | 0 | — | — |
| Premium | 250 | 100 | $4.99 | $49.99 |

---

## 11. AI Integration (Gemini)

- **Model:** Gemini 2.5 Flash
- **Proxy:** Supabase Edge Function `gemini-proxy`
- **Operations:** summarize, extract action items, brainstorm, rewrite (proofread/rephrase/emojify/elaborate/shorten/custom)
- **Token tracking:** `ai_input_tokens`, `ai_output_tokens` in profiles table
- **Credit system:** `ai_credits_used` incremented per request

---

## 12. HelpLoop SDK (In-App Support)

```dart
await HelpLoop.initialize(
  projectId: '9773e382-5e44-4c64-b64e-4da37f93164d',
  apiKey: 'pk_live_ae92a406477da2342015cb8c941821a8e9afe7c751c6e615cd3db16c4bdf2413',
  apiUrl: 'https://bwnrvdgonsqffiflcbem.supabase.co/functions/v1/helploop',
);
await HelpLoop.identify(externalId: email, email: email, name: displayName);
HelpLoop.open(context);
```

**Admin inbox:** https://web-black-five-25.vercel.app/#/projects/9773e382-5e44-4c64-b64e-4da37f93164d/inbox

> [!IMPORTANT]
> The SDK uses a **local path dependency** (`C:\My Projects\HelpLoop\sdks\flutter`). This won't work on other machines. The `supporthub-sdks/flutter/` copy in the repo has the SDK source with bug fixes applied (see `sdk_changes_report.md` in conversation artifacts).

---

## 13. Deployment

### Deploy Scripts (all require `CLOUDFLARE_API_TOKEN` in `.env`)

| Script | Build | Cloudflare Project |
|---|---|---|
| `deploy_web_app.bat` | `flutter build web --release` | `inksync` |
| `deploy_admin.bat` | `flutter build web --release` (admin_portal/) | `inksync-admin` |
| `deploy_marketing.bat` | `npm run build` (marketing/) | `inksync-marketing` |

### CI/CD (GitHub Actions)

| Workflow | Trigger | Output |
|---|---|---|
| `android_build.yml` | Push with `[build]` in commit OR manual | `inksync-release-apk` artifact |
| `android_build_aab.yml` | Manual dispatch only | `inksync-release-aab` artifact |

**GitHub Secrets:** `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`

### Android Signing

- **Keystore:** `inksync-release-key.jks` (alias: `inksync`)
- **Google Play App Signing Key SHA-1:** `C6:29:5F:18:07:25:C4:80:44:8B:24:A7:90:F0:6D:33:26:E5:D9:E4`
- Two Android OAuth clients in Google Cloud Console (upload key + Play Store signing key)

---

## 14. Environment Variables & Secrets

### Hardcoded in Dart Config Files

| File | Contains |
|---|---|
| `lib/config/supabase_config.dart` | Supabase URL, anon key, Google OAuth client IDs |
| `lib/config/stripe_config.dart` | Stripe publishable key (LIVE), checkout URLs |
| `lib/config/app_config.dart` | Firebase keys (legacy), app name/version |

### Supabase Edge Function Env Vars

| Variable | Used By |
|---|---|
| `STRIPE_SECRET_KEY` | All Stripe functions |
| `STRIPE_WEBHOOK_SECRET` | stripe-webhook |
| `STRIPE_PRODUCT_PREMIUM` | create-checkout-session |
| `SUPABASE_URL` | All functions |
| `SUPABASE_ANON_KEY` | All functions |
| `SUPABASE_SERVICE_ROLE_KEY` | All functions |
| `GEMINI_API_KEY` | gemini-proxy (vault fallback) |

### Supabase Vault Secrets

| Key | Purpose |
|---|---|
| `gemini_api_key` | Gemini API key |
| Resend API key | Collaboration invite emails |

### Local `.env`

| Variable | Purpose |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Deploy scripts |

---

## 15. Google Cloud Console

**Project:** InkSync (`inksync-496404`)

**OAuth 2.0 Client IDs:**
1. `InkSync iOS client 1` (iOS)
2. `InkSync Android client 1` (upload key SHA-1)
3. `InkSync Android client (Play Store)` (app signing key SHA-1)
4. `InkSync web` (Web application)

---

## 16. Known Issues & Technical Debt

> [!WARNING]
> **Large files needing refactoring:**
> - `note_edit_screen.dart` — **218KB** (extremely large single file)
> - `login_screen.dart` — **57KB**
> - `home_screen.dart` — **34KB**

> [!WARNING]
> **Other issues:**
> - `README.md` is outdated — still references Firebase/Firestore as primary backend
> - Dual auth services (`AuthService` + `SupabaseAuthService`) with overlapping functionality
> - `key.properties` has plain-text passwords committed (CI uses GitHub Secrets instead)
> - HelpLoop SDK uses local path dependency — won't resolve on other machines
> - RevenueCat iOS API keys are placeholders — not yet configured
> - All API keys/secrets are hardcoded in Dart files (not using env vars for the app)
> - `landing/` screen directory is empty (unused)
> - Legacy Firebase references still exist in config

---

## 17. Key Third-Party Dependencies

| Package | Version | Purpose |
|---|---|---|
| `supabase_flutter` | ^2.10.5 | Backend |
| `google_sign_in` | ^6.2.3 | Google OAuth (mobile) |
| `purchases_flutter` | ^10.1.0 | RevenueCat (iOS payments) |
| `sqflite` | ^2.4.2 | SQLite (offline-first) |
| `provider` | ^6.1.4 | State management |
| `google_fonts` | ^6.2.1 | Typography (Inter) |
| `flutter_quill` | ^11.0.0-dev.22 | Rich text editor |
| `flutter_local_notifications` | ^18.0.1 | Push notifications |
| `url_launcher` | ^6.3.1 | External links |
| `intl` | ^0.20.2 | Date formatting |
| `shared_preferences` | ^2.5.3 | Local key-value storage |
| `fl_chart` | (admin) | Admin dashboard charts |
| `go_router` | ^17.2.3 (admin) | Admin routing |

---

## 18. Play Store Listing

- **Title:** InkSync — Notes & Checklists
- **Short Description:** Simple note-taking app. Share notes, collaborate in real time & sync everywhere.
- **Category:** Productivity
- **Package:** `com.InkSync`
- **Min SDK:** 26 (Android 8.0)
- **Target SDK:** Flutter default
- **Compile SDK:** 36
