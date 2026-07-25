# ideasbugs

[![Gem Version](https://img.shields.io/gem/v/ideasbugs)](https://rubygems.org/gems/ideasbugs)
[![Downloads](https://img.shields.io/gem/dt/ideasbugs)](https://rubygems.org/gems/ideasbugs)
[![CI](https://github.com/yshmarov/ideasbugs/actions/workflows/ci.yml/badge.svg)](https://github.com/yshmarov/ideasbugs/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](MIT-LICENSE)

In-app product feedback collection for Rails. (Formerly published as
`feedback_engine` — see the [CHANGELOG](CHANGELOG.md) for the rename notes.)

`ideasbugs` adds a **"Send feedback"** widget to your app — bug reports,
feature requests, general comments, with optional screenshots — and stores
every submission in your own database. A minimal built-in dashboard lets you
browse and triage what users send. No third-party service, no data leaves your
app.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="demo-widget-dark.png">
  <img alt="The feedback widget: type, section, message, and screenshots" src="demo-widget-light.png" width="420">
</picture>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="demo-dashboard-dark.png">
  <img alt="The built-in triage dashboard: status tabs, filters, search" src="demo-dashboard-light.png" width="820">
</picture>

Both the widget and the dashboard follow the viewer's system appearance —
these screenshots are the same pages in light and dark mode.

## Why not Canny (or another feedback SaaS)?

Hosted feedback tools are great until you notice the trade: your users'
feedback lives in someone else's database, behind someone else's login, at a
per-seat price. `ideasbugs` keeps the core loop — collect, triage,
resolve — inside your app: **your database, your users, your auth, one gem.**
Attribution plugs into whatever authentication you already have, gating is a
lambda, and submissions are ordinary ActiveRecord rows you can query, export,
or wire into Slack. (A public voting board à la Canny is on the
[roadmap](https://github.com/yshmarov/ideasbugs/issues/1).)

- **Zero UI dependencies.** The widget is plain JavaScript and styles itself.
  No Tailwind, no Stimulus, no importmap, no build step. The dashboard renders
  its own styles too.
- **One line in your layout.** `<%= ideasbugs_tag %>` and you're
  collecting feedback.
- **Trigger it your way.** Use the built-in floating button, or hide it and
  open the form from any element with a `data-ideasbugs-open` attribute.
- **Screenshots included.** Users can attach up to 3 images (via Active
  Storage) — limits are configurable and enforced server-side.
- **Pluggable gating and attribution.** You decide who can send feedback, who
  can read it, and how a submission is attributed to a user.
- **Localized.** The widget follows your app's `I18n.locale`; translations ship
  for English plus 25 more languages — Arabic, Bengali, Bulgarian, Chinese
  (Simplified), Croatian, Dutch, French, German, Greek, Hindi, Indonesian,
  Italian, Japanese, Korean, Luxembourgish, Polish, Portuguese, Romanian,
  Russian, Spanish, Thai, Turkish, Ukrainian, Urdu and Vietnamese — with
  English fallbacks for everything else. RTL locales render mirrored.

## How it works

1. `ideasbugs_tag` renders a floating **Feedback** button (bottom-right).
2. Clicking it opens a small self-styled modal: type (bug / feature / other),
   an optional section select, a message, and optional screenshots.
3. The form `POST`s to the mounted engine with the page URL, the user agent,
   and (if you configure it) the current user — stored in the
   `ideasbugs_feedbacks` table.
4. You browse and triage submissions at the mount path (`/feedback`): status
   tabs (open → in review → resolved), type filter, search, screenshots
   inline.

## Requirements

- Ruby >= 3.2
- Rails >= 7.1
- Active Storage (only if you want screenshot uploads)

## Installation

```ruby
# Gemfile
gem "ideasbugs"
```

```bash
bundle install
bin/rails generate ideasbugs:install
bin/rails db:migrate
```

The generator:

- writes `config/initializers/ideasbugs.rb`,
- creates the `ideasbugs_feedbacks` migration,
- mounts the engine in `config/routes.rb`:

  ```ruby
  mount Ideasbugs::Engine => "/feedback"
  ```

Then add the widget to your layout, right before `</body>`:

```erb
<%= ideasbugs_tag %>
```

> The widget reads the CSRF token from `<meta name="csrf-token">`, which
> `csrf_meta_tags` in your layout already provides in a standard Rails app.

Boot the app and look for the **Feedback** button in the bottom-right corner.
Submissions appear at [`/feedback`](http://localhost:3000/feedback) (dashboard
access defaults to development only — see below).

## Configuration

Everything is optional; the defaults work out of the box.

```ruby
# config/initializers/ideasbugs.rb
Ideasbugs.configure do |config|
  # Who can send feedback. Return false to hide the widget and reject
  # submissions for this request. Defaults to everyone.
  config.enabled = ->(request) { true }

  # Who can browse and triage feedback at the mount path.
  # DEFAULTS TO DEVELOPMENT ONLY — override before deploying.
  config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }

  # Attribute feedback to a user (optional). Return an object responding to
  # #id, or nil. Receives the request.
  config.current_user = ->(request) { request.env["warden"]&.user }

  # Label stored for the author and shown in the dashboard.
  config.author_label = ->(user) { user.try(:email) }

  # Feedback types users can pick from. Labels come from I18n
  # (ideasbugs.kinds.<kind>).
  config.kinds = %w[bug feature other]

  # App areas shown as a select in the widget. Empty list hides the select.
  config.sections = ["Dashboard", "Billing", "Settings"]

  # Screenshot uploads (requires Active Storage).
  config.screenshots = true
  config.max_screenshots = 3
  config.max_screenshot_size = 5.megabytes

  # Per-IP throttle for the submission endpoint (Rails 7.2+; ignored on 7.1).
  # Keyword arguments for Rails' rate limiter; nil disables throttling.
  config.rate_limit = { to: 10, within: 1.minute }

  # Show the floating feedback button. Set false and trigger the form from
  # your own UI instead (see below).
  config.show_button = true

  # Fixed button text; leave nil to use the localized default.
  config.button_label = nil

  # Keep in sync with the `mount` in config/routes.rb.
  config.mount_path = "/feedback"

  # Called with each saved feedback — notify Slack, send an email, etc.
  config.on_submit = ->(feedback) { FeedbackMailer.with(feedback:).new_feedback.deliver_later }
end
```

`current_user` (and any admin gate) receives the raw request, so it works
with whatever auth you have:

```ruby
# Devise / Warden:
config.current_user = ->(request) { request.env["warden"]&.user }

# Rails 8 built-in auth (bin/rails generate authentication):
config.current_user = lambda do |request|
  token = request.cookies["session_token"]
  Session.find_signed(token)&.user if token
end
```

### Opening the form from your own UI

Prefer a nav item over the floating button? Add `data-ideasbugs-open` to
any element and (optionally) hide the button:

```ruby
config.show_button = false # optional
```

Gate the trigger with the same check the widget uses — `ideasbugs_tag`
renders nothing when `config.enabled` rejects the request, so an unguarded
trigger would be a dead button for those users. The gem ships a
`ideasbugs.title` label ("Send bug/feature request") in every bundled language, so
a localized trigger needs no keys of your own:

```erb
<% if Ideasbugs.enabled?(request) %>
  <button data-ideasbugs-open><%= t("ideasbugs.title") %></button>
<% end %>
```

### Loading the widget only where it's used

`ideasbugs_tag` in the layout puts the widget on every page. If your
only trigger lives on one page, render the tag on that page instead — for
example into the layout's `<head>` via `content_for`:

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  ...
  <%= yield :head %>
</head>

<%# app/views/users/show.html.erb — the page with the trigger %>
<% content_for :head, ideasbugs_tag %>
```

This is Turbo-safe: the script installs its document-level listeners once per
session and re-renders on `turbo:load` (see [Turbo](#turbo)), whether it
arrives on the first page load or a later visit. The trade-off: a
`data-ideasbugs-open` element on a page that never rendered the tag
silently does nothing — if triggers may appear on several pages, keep the tag
in the layout.

### Protecting the dashboard

The dashboard (index/show/triage) is gated by `config.authorize_admin`, which
defaults to **development only** so a fresh install can never leak feedback in
production. Grant access however your app resolves admins:

```ruby
# Devise:
config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }

# Basic auth, feature flag, IP allowlist — anything based on the request:
config.authorize_admin = ->(request) { Flipper.enabled?(:feedback_admin) }
```

You can also wrap the mount in your own routing constraint (the lambda still
applies on top):

```ruby
authenticate :user, ->(user) { user.admin? } do
  mount Ideasbugs::Engine => "/feedback"
end
```

### Screenshots

Uploads use Active Storage: `bin/rails active_storage:install` if you haven't
already. Limits (`max_screenshots`, `max_screenshot_size`) are enforced
server-side and shown as a hint in the widget. If Active Storage isn't loaded,
the upload control simply doesn't render and uploads are rejected.

### Notifications

`config.on_submit` runs inline after each save — keep it fast or hand off to a
job:

```ruby
config.on_submit = ->(feedback) do
  SlackNotifier.post("New #{feedback.kind}: #{feedback.message.truncate(100)}")
end
```

### Localizing the widget

Every string resolves through Rails I18n under the `ideasbugs.*` scope
and follows the current `I18n.locale`. Missing keys fall back to English. To
add a language or reword the bundled copy, define the keys in your own locale
files (yours win over the gem's):

```yaml
# config/locales/nl.yml
nl:
  ideasbugs:
    button: "Feedback"
    title: "Feedback versturen"
    kinds:
      bug: "Fout melden"
      feature: "Functie aanvragen"
      other: "Overig"
    # …see config/locales/ideasbugs.en.yml for the full key list
```

Custom kinds get their labels the same way (`ideasbugs.kinds.<kind>`),
falling back to `kind.humanize`.

### Light / dark / system appearance

Both the widget and the dashboard follow the operating-system appearance via
`prefers-color-scheme` — no configuration needed.

## Working with feedback in code

Submissions are ordinary records:

```ruby
Ideasbugs::Feedback.where(status: "open").newest_first.each do |feedback|
  puts "[#{feedback.kind}] #{feedback.message} — #{feedback.author_label}"
end
```

Each row stores `kind`, `section`, `message`, `status` (`open`, `in_review`,
`resolved`), `page_url`, `user_agent`, and optional `author_id` /
`author_label`. Screenshots are Active Storage attachments
(`feedback.screenshots`).

## Security

- Submission and dashboard access are both gated **on the server** for every
  request; the dashboard denies everything outside development until you
  configure `authorize_admin`.
- Screenshots are **streamed through the dashboard's own gate**, never linked
  as public Active Storage blob URLs — a screenshot can contain anything a
  user's screen showed, so it is only reachable by someone who passes
  `authorize_admin`, regardless of how your app configures blob access.
- The submission endpoint is **rate-limited per IP** (10/minute by default,
  via Rails' built-in limiter on Rails 7.2+), so one user or bot can't flood
  your database with megabytes of uploads.
- Screenshot count, size, and content type (images only) are validated
  server-side, regardless of what the client claims.
- The widget code carries the request's Content-Security-Policy nonce (the
  same one `ActionDispatch` emits), so it runs under a nonce-based
  `script-src` policy with no configuration. The runtime config ships as a
  `<script type="application/json">` block (data, not code), so it needs no
  nonce and stays correct across Turbo visits.
- Author attribution is stored as loose fields (no foreign key into your user
  table), so the gem never couples to your user model.

## Turbo

Works with Turbo Drive out of the box. Turbo replaces `<body>` on every visit,
which would take the floating button with it, so the widget registers its
document-level listeners once and re-renders on `turbo:load`.

## Development

```bash
bin/setup        # or: bundle install
bundle exec rake test        # unit + integration
bundle exec rake test:system # browser tests (headless Chrome)
bundle exec rubocop
```

Tests run against a dummy Rails app under `test/dummy`; the widget itself is
covered by Capybara system tests in a real browser. CI runs the suite across
Rails 7.1 / 7.2 / 8.0 / 8.1 and Ruby 3.2–3.4 (per-version Gemfiles live in
`gemfiles/`).

## License

Released under the [MIT License](MIT-LICENSE).
