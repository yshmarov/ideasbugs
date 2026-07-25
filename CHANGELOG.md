# Changelog

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
