# frozen_string_literal: true

Ideasbugs.configure do |config|
  # Who can send feedback. Return false to hide the widget and reject
  # submissions for this request. Defaults to everyone.
  # config.enabled = ->(request) { true }

  # Who can browse and triage feedback at the mount path. Defaults to
  # development only — override before deploying.
  # config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }
  #
  # Render the dashboard inside your app's admin layout. Default: the gem's
  # standalone dashboard layout.
  # config.admin_layout = "admin/application"

  # Attribute feedback to a user (optional). Return an object responding to
  # #id, or nil. Receives the request.
  # Devise / Warden:
  # config.current_user = ->(request) { request.env["warden"]&.user }
  #
  # Rails 8 built-in auth (bin/rails generate authentication):
  # config.current_user = lambda do |request|
  #   token = request.cookies["session_token"]
  #   Session.find_signed(token)&.user if token
  # end

  # Label stored for the author and shown in the dashboard.
  # config.author_label = ->(user) { user.try(:email) }

  # Multi-tenancy (optional). Give each customer/tenant its own board — its own
  # widget submissions and its own triage dashboard. Return an opaque key
  # (nil = one global board, the default). A GlobalID is the recommended key
  # and matches the `has_feedback` model concern; an id, subdomain or slug work
  # too. The gem never needs to know what your tenant is. An admin then sees
  # only their tenant's board.
  # config.tenant = ->(request) { Current.organization&.to_gid&.to_s }
  #
  # Then, optionally, `has_feedback` for `customer.feedback`:
  #   class Customer < ApplicationRecord
  #     has_feedback
  #   end

  # Feedback types users can pick from. Labels come from I18n
  # (ideasbugs.kinds.<kind>).
  # config.kinds = %w[bug feature other]

  # App areas shown as a select in the widget. Empty list hides the select.
  # config.sections = ["Dashboard", "Billing", "Settings"]

  # Screenshot uploads (requires Active Storage).
  # config.screenshots = true
  # config.max_screenshots = 3
  # config.max_screenshot_size = 5.megabytes
  #
  # Store screenshots on a specific Active Storage service from
  # config/storage.yml, such as a dedicated bucket or folder. Default: your
  # environment's default service.
  # config.storage_service = :ideasbugs_uploads

  # Per-IP throttle for the submission endpoint (Rails 7.2+; ignored on 7.1).
  # Keyword arguments for Rails' rate limiter; nil disables throttling.
  # config.rate_limit = { to: 10, within: 1.minute }

  # Show the floating feedback button. Set false and add
  # `data-ideasbugs-open` to any element to trigger the form yourself.
  # config.show_button = true

  # Fixed button text; leave nil to use the localized default.
  # config.button_label = nil

  # Default mount path used by `mount_ideasbugs`.
  # Override only if you mount the engine manually.
  # config.mount_path = "/feedback"

  # Called with each saved feedback — notify Slack, send an email, etc.
  # config.on_submit = ->(feedback) { FeedbackMailer.with(feedback:).new_feedback.deliver_later }
end
