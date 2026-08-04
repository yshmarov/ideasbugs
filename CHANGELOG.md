# Changelog

## 0.9.0

- **One design system across the family.** The stylesheet now opens with a
  shared core — the colour tokens, `.page-head`, `.tabs`, `.filters`, `.card`,
  `.badge`, buttons and form controls, and the `.dashboard-shell` +
  `.record-row` + `.detail-panel` two-pane dashboard — identical in all five
  gems of the family, apart from the `--ib-` prefix. The five had drifted:
  sidebars between 380px and 430px, reading columns between 860px and 1020px,
  two different tab styles and three different button styles. The sidebar is
  now 330–430px everywhere, a reading page 1020px, a dashboard 1280px.
  Everything below the `GEM-SPECIFIC` banner is what only this gem has.
- **The dashboard markup uses the shared class names.** `.triage-shell`,
  `.triage-sidebar` and `.triage-detail` are `.dashboard-shell`,
  `.dashboard-sidebar` and `.dashboard-detail`; `.feedback-list`,
  `.feedback-row`, `.feedback-main`, `.feedback-topline`, `.feedback-message`,
  `.feedback-meta` and `.feedback-time` are `.record-*`, with
  `.feedback-message` becoming `.record-copy`; `.feedback-panel` is
  `.detail-panel`; the attachment count sits in `.record-side`. If you styled
  or scripted any of those names in a host app, that is the breaking change —
  no configuration, route or database change is involved.
- **The narrow-screen rules work again.** The `max-width: 760px` block sat above
  the component rules it means to override, and CSS nesting adds no specificity,
  so the desktop grid won every tie: showing one pane at a time on a phone had
  quietly stopped working. The media query moved to the end of the file.
- Smaller fixes that came with the shared core: a submit input is styled as a
  button rather than a full-width field, the filter row keeps its search box and
  button on one line, and a `code.key` truncates inside a list row instead of
  wrapping over three lines.

## 0.8.0

- **`config.admin_layout` now works on its own.** The dashboard's stylesheet was
  declared in the gem's layout, so replacing that layout dropped it and the
  dashboard rendered unstyled. It moves into the views, so every layout gets it
  with nothing asked of the host.
- **The dashboard stylesheet no longer claims selectors it does not own.** It
  styled bare `*`, `body` and `a`, and its `.container`, `.card` and `.tabs` are
  names other frameworks use too. Component rules now nest inside an
  `.ib-dashboard` wrapper the views render, and every custom property is `--ib-`
  prefixed — that collision ran both ways, so a host defining `--bg` recoloured
  the dashboard just as easily.
- **Added `config.base_controller_class`.** Name the controller your own admin
  inherits from and the dashboard adopts its layout, helpers, authentication and
  request context. Default is unchanged.
- **`create` moved to `Ideasbugs::SubmissionsController`.** One controller served
  both the widget's write endpoint and the triage actions, so
  `base_controller_class` would have put staff authentication in front of every
  bug report. `POST /feedbacks` now routes there; the URL is unchanged. If you
  referenced `Ideasbugs::FeedbacksController#create`, that is the breaking change
  in this release. The per-IP rate limiter moved with the action.
- **Migrations follow the host's `primary_key_type`,** the same
  `Rails.configuration.generators` lookup Rails' own Active Storage migration
  does. A uuid-keyed app has a uuid `active_storage_attachments.record_id`, so a
  bigint table here could never hold a screenshot: `attach` raised
  `NotNullViolation`. A host that set nothing gets an identical migration.
- A `BackboneTest` now fails the build on any of the above regressing.

## 0.7.8

- Adds `AGENTS.md`: install and integration instructions written for coding
  agents — the request-shaped config lambdas, the `/feedback` mount path, why
  the status strings are not an enum, and the mistakes agents actually make. It
  ships inside the gem, so `cat "$(bundle show ideasbugs)/AGENTS.md"` works from
  a host app.
- The dummy app pins `queue_adapter = :test` for the test suite. Attaching a
  screenshot enqueues Active Storage's analysis job, and the default `:async`
  adapter runs it on a background thread with its own database connection —
  writes no test transaction covers, which is how a suite starts failing
  order-dependently in a test that never created a row. No effect on the gem
  itself.

## 0.7.7 (2026-08-01)

- Added `Ideasbugs::Seeds.load!` and a `rake ideasbugs:seed_demo` task that
  create or refresh a small set of demo feedback records, so a freshly mounted
  dashboard has realistic content to look at. Seeding is idempotent and
  accepts an optional `tenant:`.

## 0.7.6 (2026-07-31)

- Fixed the trusted publishing workflow by building and pushing the gem
  directly with RubyGems OIDC credentials after the test suite passes.

## 0.7.5 (2026-07-31)

- Added `config.admin_layout`, letting host apps render the Ideasbugs dashboard
  inside their own admin layout while keeping the standalone gem layout as the
  default.

## 0.7.4 (2026-07-31)

- Redesigned the admin feedback dashboard into a two-column triage layout with
  status filters, a selected-record pane, and refreshed before/after
  screenshots.
- Kept standalone feedback show pages working independently, including
  scrollable detail content on narrow screens.

## 0.7.3 (2026-07-31)

- Added `mount_ideasbugs at: "/feedback"` as the install-time route helper,
  keeping `config.mount_path` synchronized with the mounted engine path while
  preserving manual `mount Ideasbugs::Engine` compatibility.
- Extracted the dashboard stylesheet into a same-origin, fingerprinted
  `/dashboard.css` endpoint and added CSP meta tags to the dashboard layout.
  The public widget remains pipeline-free and controller-served.
- New `config.storage_service`: store screenshots on a named Active Storage
  service from the host's `config/storage.yml` instead of the environment
  default. Point it at a dedicated bucket, folder, or provider-specific service
  entry to keep feedback screenshots separate from the rest of the app's media.
  `nil` keeps today's behavior.

## 0.7.2 (2026-07-30)

- Shipped the `IdeasBugs` admin dashboard title key in every bundled locale,
  matching the brand-title default across translated installations.

## 0.7.1 (2026-07-30)

- Renamed the default admin dashboard title to `IdeasBugs` while keeping it
  overridable through `ideasbugs.dashboard.title`.

## 0.7.0 (2026-07-27)

- **Mobile keyboard-safe dialog.** On phones the full-screen dialog
  (`height:100dvh`) no longer hides its actions row behind the on-screen
  keyboard. iOS Safari raises the keyboard without resizing fixed `100dvh`
  elements; the widget now pins `#idb-dialog` to the visible viewport via the
  `visualViewport` API while the dialog is open and the `(max-width:480px)`
  media query matches. Desktop and browsers without `visualViewport` are
  unchanged (both are guarded no-ops). Shared UX fix across the gem family.
- The type "Type" select is no longer auto-focused when the form opens.
  Focusing a `<select>` on iOS immediately pops the native picker, which looked
  broken on mount; the message textarea is focused instead. Tab still reaches
  the select and the focus trap is unchanged, so keyboard access is preserved.

## 0.6.1 (2026-07-26)

- The widget's injected stylesheet now refreshes when its content changes
  instead of once-and-never-again — so a shipped widget update takes effect on
  the next Turbo visit instead of needing a full page reload (Turbo keeps
  `<head>` across visits, which could otherwise pin old CSS while fresh
  widget.js runs). Backported from livechat 0.4.5.

## 0.6.0 (2026-07-26)

- **Multi-tenancy.** Give each customer/tenant its own board — its own widget
  submissions and its own triage dashboard — via one resolver:
  `config.tenant = ->(request) { Current.organization&.to_gid&.to_s }`. The key
  is an opaque string (GlobalID, id, subdomain, slug); the gem takes no foreign
  key into your models, exactly like author attribution. Every submission is
  stamped and the dashboard (plus screenshot access) scopes to the resolved
  tenant. Authorization composes: `authorize_admin` says who's an admin,
  `tenant` says which tenant, so a customer's admin sees only their own — and a
  cross-tenant id 404s instead of leaking.
- Optional `has_feedback` model concern (veneer over the string key, no new
  coupling): `customer.feedback.open` — plus `Ideasbugs.for(record)`.
- **Single-tenant apps are unchanged** — `config.tenant` defaults to nil, one
  global board. Upgrading: the `tenant` column is additive and nullable; run
  `bin/rails generate ideasbugs:tenant && bin/rails db:migrate` (fresh installs
  already include it). Existing rows keep a nil tenant.

## 0.5.5 (2026-07-25)

- The dashboard's **Section** column now only appears when it carries
  information — when sections are configured (`config.sections`) or some
  record already has one. Apps that don't use sections no longer see a
  permanently blank column.

## 0.5.4 (2026-07-25)

- Docs: show how to wire current_user with Rails 8's built-in authentication
  (bin/rails generate authentication), alongside the existing Devise/Warden
  example — in the README and the generated initializer.

## 0.5.3 (2026-07-25)

- The widget's dynamic messages are now announced to screen readers: the
  validation/save error paragraph is a `role="alert"` region created before
  any text lands in it, and the post-submit thanks note is an
  `aria-live="polite"` status region inserted empty and then filled, so the
  announcement actually fires.
- The page behind the open widget dialog no longer scrolls: opening the
  dialog locks `<html>` overflow and closing it restores the previous value.
  Because the lock lives on `<html>` (which survives Turbo body swaps), the
  per-visit render step also releases a stale lock whenever the overlay is
  no longer in the DOM.

## 0.5.2 (2026-07-25)

- **Fixed: the widget went dead after Turbo Drive navigations under a
  nonce-based CSP.** The widget code used to be inlined as a nonce'd
  `<script>` block. Turbo Drive soft visits swap the `<body>` and re-execute
  body scripts against the *original* page's CSP header, so the freshly
  minted inline nonce was refused and the widget never booted — until the
  user hard-reloaded. The code is now served by the engine as a same-origin,
  content-fingerprinted script (`<mount_path>/widget.js?v=<md5>`), which
  `script-src 'self'` covers on every visit, first or soft. The fingerprinted
  URL is immutable (new code means a new URL) and is cached publicly for a
  year; any other `?v` only ETag-revalidates. The `nonce` attribute is still
  stamped on the tag for hosts whose `script-src` has no `'self'`. The config
  `type="application/json"` block is unchanged and stays inline — it is data,
  not code, and needs no nonce.

## 0.5.1 (2026-07-25)

- The widget dialog is now full-screen on mobile (≤ 480px): edge-to-edge,
  `100dvh` tall, no rounded corners.
- Form controls render at 16px on mobile widths, so iOS no longer zooms the
  page when an input gains focus.
- The action row respects `env(safe-area-inset-bottom)`, keeping the buttons
  above the home indicator on notched phones.
- The dialog's scroll area uses `overscroll-behavior: contain`, so reaching
  the end of the form no longer scrolls the page behind it.

## 0.5.0 (2026-07-25)

**The gem is now `ideasbugs`** (formerly `feedback_engine`). Full rebrand:

- Gem name `ideasbugs`, module `Ideasbugs`, repository
  github.com/yshmarov/ideasbugs.
- Table `ideasbugs_feedbacks` (was `feedback_engine_feedbacks`), helper
  `ideasbugs_tag` (was `feedback_engine_tag`), I18n scope `ideasbugs.*`,
  initializer `config/initializers/ideasbugs.rb`, generator
  `ideasbugs:install`, widget data attributes `data-ideasbugs-*`.
- **Upgrading from feedback_engine:** swap the gem in your Gemfile, rename
  the initializer and its `FeedbackEngine` constants to `Ideasbugs`, update
  the layout tag/trigger attributes, remount the engine, and migrate:

  ```ruby
  rename_table :feedback_engine_feedbacks, :ideasbugs_feedbacks
  # Existing screenshot attachments keep working after:
  # UPDATE active_storage_attachments SET record_type = 'Ideasbugs::Feedback'
  #   WHERE record_type = 'FeedbackEngine::Feedback'
  ```

  Versions ≤ 0.4.2 remain published under the old name; entries below this
  point describe releases made as `feedback_engine`.

## 0.4.2 (2026-07-25)

- The default title CTA (`feedback_engine.title`, used as the modal heading
  and by host-rendered triggers) now reads "Send bug/feature request" instead
  of "Send feedback", localized in all 26 bundled languages.
- The test suite migrated from RSpec to Minitest (development-only change;
  nothing in the shipped gem is affected). `bundle exec rake test` and
  `rake test:system` replace the rspec commands.

## 0.4.1 (2026-07-23)

- The widget JavaScript moved from `app/assets/` to `lib/` (it was always
  inlined server-side, never served as an asset). Rails auto-registers every
  engine's `app/assets/*` directory with the host's asset pipeline, so
  Propshaft hosts were ingesting the file into their asset namespace under
  the bare logical name `widget.js` — colliding with any other gem or host
  file of the same name — and needlessly digesting a public copy at
  precompile. The gem is now invisible to Sprockets/Propshaft entirely.
  No behavior change.

## 0.4.0 (2026-07-22)

- Removed the clipboard-paste / drag-and-drop / file-chips screenshot intake
  added in 0.3.0 — pasted files all arrive as `image.png` and the extra UI
  wasn't worth its complexity. Screenshots are back to a plain file input.

## 0.3.0 (2026-07-22)

- Screenshots can be pasted (Cmd/Ctrl+V) or dragged & dropped anywhere on
  the feedback form, not just picked via the file dialog. Selected files show
  as removable chips; non-images are ignored and the configured maximum is
  enforced at intake. (Removed again in 0.4.0.)
- The dialog traps Tab focus while open and is labelled for screen readers
  (`aria-labelledby`).
- Dashboard search across message, author, and section (case-insensitive,
  LIKE-wildcard-safe, works on SQLite/PostgreSQL/MySQL).
- A raising `on_submit` hook no longer turns a saved submission into a 500 —
  the error is logged and the widget still gets its 201.
- Releases are automated via RubyGems trusted publishing: pushing a `v*` tag
  builds and publishes the gem from CI (one-time setup on rubygems.org
  required; see `.github/workflows/release.yml`).

## 0.2.0 (2026-07-22)

Security:

- Dashboard screenshots are now streamed through an engine route gated by
  `config.authorize_admin`, instead of linking public Active Storage blob
  URLs. Screenshots can contain anything a user's screen showed; they are no
  longer reachable without passing the dashboard's own authorization,
  regardless of how the host configures blob access. (Also fixes broken
  images in apps that lock their blob endpoints down.)

Added:

- Per-IP rate limiting on the submission endpoint via Rails' built-in
  limiter (Rails 7.2+; no-op on 7.1). Default 10 submissions/minute; tune or
  disable with `config.rate_limit`. Localized 429 message in all 26 languages.
- Browser-level test suite for the widget (Capybara + headless Chrome):
  open/submit/validation/screenshot-attach/Escape/custom-trigger flows.
- CI now tests the full Rails support matrix: 7.1, 7.2, 8.0, and 8.1 across
  Ruby 3.2–3.4.

## 0.1.0 (2026-07-21)

Initial release.

- Drop-in feedback widget (`<%= feedback_engine_tag %>`): floating button +
  self-styled modal with type, optional section, message, and optional
  screenshots. Plain JavaScript, no build step, CSP-nonce aware, Turbo-safe,
  follows system light/dark appearance and the app's `I18n.locale` (RTL
  supported).
- `feedback_engine_feedbacks` table with kind, section, message, status
  (open / in_review / resolved), page URL, user agent, and loose author
  attribution.
- Screenshot uploads via Active Storage with server-side count / size /
  content-type validation (configurable limits).
- Built-in triage dashboard at the mount path: status tabs with counts, type
  filter, detail view with screenshots, status transitions, delete. Gated by
  `config.authorize_admin` (development-only by default).
- Configuration hooks: `enabled`, `authorize_admin`, `current_user`,
  `author_label`, `kinds`, `sections`, `screenshots` limits, `show_button`,
  `button_label`, `mount_path`, `on_submit`.
- `feedback_engine:install` generator (initializer, migration, mount).
- Widget translations for English plus 25 more languages (ar, bg, bn, de, el,
  es, fr, hi, hr, id, it, ja, ko, lb, nl, pl, pt, ro, ru, th, tr, uk, ur, vi,
  zh-CN), with a parity spec keeping every locale's key set and interpolation
  placeholders in sync.
