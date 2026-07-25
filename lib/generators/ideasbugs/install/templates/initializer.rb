# frozen_string_literal: true

Ideasbugs.configure do |config|
  # Who can send feedback. Return false to hide the widget and reject
  # submissions for this request. Defaults to everyone.
  # config.enabled = ->(request) { true }

  # Who can browse and triage feedback at the mount path. Defaults to
  # development only — override before deploying.
  # config.authorize_admin = ->(request) { request.env["warden"]&.user&.admin? }

  # Attribute feedback to a user (optional). Return an object responding to
  # #id, or nil. Receives the request.
  # config.current_user = ->(request) { request.env["warden"]&.user }

  # Label stored for the author and shown in the dashboard.
  # config.author_label = ->(user) { user.try(:email) }

  # Feedback types users can pick from. Labels come from I18n
  # (ideasbugs.kinds.<kind>).
  # config.kinds = %w[bug feature other]

  # App areas shown as a select in the widget. Empty list hides the select.
  # config.sections = ["Dashboard", "Billing", "Settings"]

  # Screenshot uploads (requires Active Storage).
  # config.screenshots = true
  # config.max_screenshots = 3
  # config.max_screenshot_size = 5.megabytes

  # Per-IP throttle for the submission endpoint (Rails 7.2+; ignored on 7.1).
  # Keyword arguments for Rails' rate limiter; nil disables throttling.
  # config.rate_limit = { to: 10, within: 1.minute }

  # Show the floating feedback button. Set false and add
  # `data-ideasbugs-open` to any element to trigger the form yourself.
  # config.show_button = true

  # Fixed button text; leave nil to use the localized default.
  # config.button_label = nil

  # Keep in sync with the `mount` in config/routes.rb.
  # config.mount_path = "/feedback"

  # Called with each saved feedback — notify Slack, send an email, etc.
  # config.on_submit = ->(feedback) { FeedbackMailer.with(feedback:).new_feedback.deliver_later }
end
