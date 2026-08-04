# AGENTS.md

Instructions for coding agents. Two audiences:

- **[Installing ideasbugs into a Rails app](#installing-into-a-rails-app)** — you are working in a host app and were asked to add product feedback, bug reports, or a feature-request board.
- **[Working on the gem itself](#working-on-the-gem-itself)** — you are working in this repository.

Requirements: Ruby >= 3.2, Rails >= 7.1. Active Storage only for screenshots. The widget needs the CSRF token from `csrf_meta_tags`, which a standard Rails layout already has.

If you are in a host app and this file is not in front of you, it ships inside the gem: `cat "$(bundle show ideasbugs)/AGENTS.md"`.

---

## Installing into a Rails app

### 1. Install

```bash
bundle add ideasbugs
bin/rails generate ideasbugs:install
bin/rails db:migrate
```

The generator writes `config/initializers/ideasbugs.rb`, one migration (`ideasbugs_feedbacks`), and `mount_ideasbugs at: "/feedback"` into `config/routes.rb`. Note the mount path is **`/feedback`**, not `/ideasbugs`. Read the initializer it wrote — every option is documented there in comments, and it is the source of truth over any summary of it, including this file.

Every `config.…` line below belongs inside the `Ideasbugs.configure do |config|` block in that initializer. Uncomment and edit in place rather than appending a second `configure` block.

### 2. Wire the three things the generator cannot

**a. The widget tag.** Nothing appears until this is on the page:

```erb
<%# app/views/layouts/application.html.erb, before </body> %>
<%= ideasbugs_tag %>
```

The helper is injected into ActionView by the engine — no include, no import, no asset pipeline entry. A floating **Feedback** button appears bottom-right.

**b. `authorize_admin` — do this before deploying.** The dashboard at `/feedback` defaults to **development only**. It fails closed, so shipping without this is not an open dashboard — it is a 403 reading "Forbidden. Set Ideasbugs.config.authorize_admin to grant access."

Note the asymmetry, and that it is deliberate: **`enabled` defaults to everyone** (real users in production are the point of feedback collection) while **`authorize_admin` defaults to nobody outside development**.

```ruby
config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }
```

**c. Attribution**, if the app has users. Optional, but without it every submission is anonymous.

```ruby
config.current_user = ->(request) { request.env["warden"]&.user }
config.author_label = ->(user) { user.email }   # the short label stored + shown
```

> **`enabled`, `authorize_admin`, `current_user` and `tenant` receive the raw `request`, not a controller.** Writing `->(request) { current_user }` is the most common mistake here — that method does not exist in this scope. Resolve the user *from the request*: Warden env, a signed cookie, `Current.user` if middleware already set it. `author_label` is the exception: it receives whatever `current_user` returned.

Rails 8 built-in auth:

```ruby
config.current_user = lambda do |request|
  token = request.cookies["session_token"]
  Session.find_signed(token)&.user if token
end
```

### 3. Verify

```bash
bin/rails routes | grep ideasbugs     # engine mounted
bin/rails ideasbugs:seed_demo         # optional sample feedback, idempotent
```

Then in the running app: load any page, confirm the Feedback button appears, send one, and triage it at `/feedback`.

### Shaping the widget

```ruby
config.kinds = %w[bug feature other]          # labels resolve through I18n (ideasbugs.kinds.<kind>)
config.sections = ["Billing", "Dashboard"]     # [] hides the select entirely
config.show_button = false                     # then open it from your own UI
config.button_label = "Report a problem"       # nil = localized default
```

With `show_button = false`, any element carrying `data-ideasbugs-open` opens the form — put it in a menu, a footer, a help panel.

### Screenshots

`config.screenshots` is on by default but **requires Active Storage in the host app** (`rails active_storage:install`); the widget hides the upload control when it is off or Active Storage is absent, and the config exposes `screenshots_enabled?` for exactly that pair of conditions. Caps: `max_screenshots` (3), `max_screenshot_size` (5 MB), both enforced server-side. Images stream through the dashboard's own gate at `/feedback/feedbacks/:id/screenshots/:id` — **never a public blob URL**. Do not build your own blob links.

### Statuses

`open → in_review → resolved`, as plain strings in `Ideasbugs::Feedback::STATUSES` with a scope per status (`Feedback.open`, `.in_review`, `.resolved`) plus `newest_first`. Deliberately not an Active Record enum — `open` as an enum scope would collide with `Kernel#open`. Do not "modernize" it into an enum.

### Multi-tenancy

One resolver returning an **opaque key** — GlobalID, id, subdomain, slug. The gem never takes a foreign key into host models:

```ruby
config.tenant = ->(request) { Current.customer&.to_gid&.to_s }
```

Optional sugar on a host model (`has_feedback` is available on every Active Record class already):

```ruby
class Customer < ApplicationRecord
  has_feedback   # keyed by to_gid.to_s — must match config.tenant
end
customer.feedback.open
```

`bin/rails generate ideasbugs:tenant` exists **only** to add the `tenant` column to installs made before it existed. A fresh install already has it, and running that generator will fail on a duplicate column. Do not run it as part of a new install.

### Do not

- **Do not copy the widget JavaScript into `app/javascript`, or add a `<script>` tag for it.** `ideasbugs_tag` renders what is needed and the engine serves the code same-origin. There is no build step and nothing for esbuild/importmap/Tailwind to know about.
- **Do not rebuild the dashboard, and do not edit views inside the gem.** To put it inside an admin you already have, set `config.base_controller_class = "Admin::BaseController"` — it inherits that controller's layout, helpers, authentication and request context. For the shell alone, `config.admin_layout = "admin/application"`. Both work with nothing else wired up: the dashboard's own assets are declared by its views, not the layout.
- **Do not expose screenshots by blob URL** — the gated route exists so a leaked signed URL cannot hand over a customer's screenshot.
- **Do not set config outside the initializer.** `rate_limit` in particular is read once when the controller class loads; assigning config per-request mutates it process-wide.
- **Do not convert the status strings to an enum** (see above).

### Configuration worth knowing

Everything is optional; a fresh install works with zero config. Full list with comments is in the generated initializer.

| Option | Default | Note |
| --- | --- | --- |
| `authorize_admin` | development only | **Who can read the dashboard. Set before deploying.** |
| `enabled` | everyone | Per-request gate for the widget and submissions |
| `current_user` | `nil` | Receives the request |
| `author_label` | email, else `to_s` | Receives the user |
| `tenant` | `nil` | One board per tenant — see [Multi-tenancy](#multi-tenancy) |
| `kinds` | `bug feature other` | Labels via `ideasbugs.kinds.<kind>` |
| `sections` | `[]` | App areas as a select; empty hides it |
| `screenshots` | `true` | Needs Active Storage; inert without it |
| `max_screenshots`, `max_screenshot_size` | `3`, `5.megabytes` | Enforced server-side |
| `storage_service` | app default | A `storage.yml` key for a dedicated bucket |
| `show_button`, `button_label` | `true`, localized | `false` = open from `data-ideasbugs-open` |
| `base_controller_class` | `ActionController::Base` | Controller the dashboard inherits. Name your admin's and it adopts that layout, helpers, authentication and request context. Public endpoints never inherit it. |
| `admin_layout` | `ideasbugs/application` | Render inside your admin shell |
| `rate_limit` | `{ to: 10, within: 60 }` | Rails 7.2+; ignored on 7.1. `nil` disables |
| `mount_path` | `"/feedback"` | Keep in sync with `mount_ideasbugs at:` |
| `on_submit` | no-op | Runs inline after save — Slack, email, a ticket |

### Common failure modes

| Symptom | Cause |
| --- | --- |
| `NameError` for one of your own helpers in the dashboard | `isolate_namespace` scopes `helper` to the engine. Use `config.base_controller_class` so the dashboard inherits your helpers, rather than `admin_layout` alone. |
| `NotNullViolation` attaching a file on a uuid-keyed app | The tables were generated bigint. Set `primary_key_type` in `config.generators` before installing, or migrate them to uuid. |
| `/feedback` returns 403 "Set Ideasbugs.config.authorize_admin to grant access" | Exactly what it says: still at the development-only default |
| No Feedback button | `ideasbugs_tag` missing from the rendered layout, `config.enabled` false, or `show_button = false` with no opener of your own |
| Submissions rejected with an invalid-token error | The layout is missing `csrf_meta_tags` |
| No screenshot upload control | Active Storage not installed, or `screenshots = false` |
| `ideasbugs:tenant` fails on a duplicate column | It is an upgrade generator for pre-tenant installs; a fresh install already has the column |
| `undefined local variable current_user` in the initializer | A gate lambda treated its argument as a controller. It is a `request` |

---

## One family

`testimonials`, `livechat`, `product_tours`, `i18n_proofreading` are the sibling engines. Same install shape, same host hooks (`base_controller_class`, `admin_layout`), same scoped dashboard CSS, same `primary_key_type`-aware migrations — so what you learn here transfers.

## Working on the gem itself

```bash
bundle exec rake test            # minitest, dummy app under test/dummy
bundle exec rake test:system     # browser tests, separate task
bundle exec rubocop              # must be clean
BUNDLE_GEMFILE=gemfiles/rails_7.1.gemfile bundle exec rake test   # 7.1, 7.2, 8.0, 8.1 in gemfiles/
```

Layout: `app/` controller, model, dashboard views · `lib/ideasbugs/` config, widget JS, seeds, engine, `has_feedback` · `lib/generators/ideasbugs/` install and tenant · `config/locales/` · `test/` minitest with `test/dummy` as the host app, system tests excluded from the default task.

Conventions this codebase holds to — follow them rather than the first thing that works:

- **Multi-tenancy is an opaque string key, never a foreign key.** `config.tenant` returns whatever the host wants; `has_feedback` is a veneer over `Feedback.for_tenant`. No association, no `owner_type` coupling.
- **Active Storage is optional at runtime.** `screenshots_enabled?` checks the switch *and* whether the constant is defined, so an app without Active Storage gets a working widget rather than an exception.
- **Attachments stream through the engine's gate**, never a public blob URL.
- **The widget is plain JS served same-origin by the engine** — no build step, no framework.
- **The dummy app pins `config.active_job.queue_adapter = :test`.** Do not remove it or let it drift back to the `:async` default. Attaching a screenshot enqueues Active Storage's analysis job, and `:async` runs it on a background thread that checks out its own connection — writes no test transaction covers, landing in the middle of whatever runs next. That is a suite that fails order-dependently in a test which never created a row, and it is miserable to trace back.
- Every user-facing change bumps `lib/ideasbugs/version.rb` and adds a `CHANGELOG.md` entry that says what it costs, not only what it adds.
- Commit messages are prose that explains the tradeoff — read `git log` before writing one.
