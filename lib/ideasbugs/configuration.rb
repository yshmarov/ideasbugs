# frozen_string_literal: true

module Ideasbugs
  # Host-tunable settings. Everything has a safe default, so a fresh install
  # works with zero configuration; the hooks below let an app decide who can
  # send feedback, who can read it, and how submissions are attributed.
  class Configuration
    # Per-request gate for the widget and the submission endpoint. Return false
    # to hide the widget and reject submissions for this request. Receives the
    # request. Defaults to everyone — feedback collection is meant for real
    # users in production.
    attr_accessor :enabled

    # Per-request gate for the built-in dashboard (browse and triage feedback).
    # Receives the request. Defaults to development only — override it before
    # deploying, e.g. with an admin check.
    attr_accessor :authorize_admin

    # Resolve the current user for attribution (optional). Return an object
    # responding to #id, or nil. Receives the request.
    attr_accessor :current_user

    # Turn a resolved user into a short label stored alongside the feedback and
    # shown in the dashboard. Receives whatever #current_user returned.
    attr_accessor :author_label

    # The feedback types a user can pick from. Labels resolve through I18n
    # (`ideasbugs.kinds.<kind>`), so you can rename or add kinds freely.
    attr_accessor :kinds

    # Optional list of app areas ("Billing", "Dashboard", …) shown as a select
    # in the widget. Leave empty to hide the select entirely.
    attr_accessor :sections

    # Allow screenshot uploads. Requires Active Storage in the host app; the
    # widget hides the upload control when this is false or Active Storage is
    # not set up.
    attr_accessor :screenshots

    # Upload limits, enforced server-side and mirrored in the widget.
    attr_accessor :max_screenshots, :max_screenshot_size

    # Per-IP throttle for the public submission endpoint, as keyword arguments
    # for Rails' rate limiter (Rails 7.2+; ignored on 7.1). Read once when the
    # controller loads — set it in an initializer. nil disables throttling.
    attr_accessor :rate_limit

    # Show the floating feedback button. Set false to trigger the widget from
    # your own UI instead: any element with a `data-ideasbugs-open`
    # attribute opens the form.
    attr_accessor :show_button

    # Text on the floating button. Leave nil to use the localized default
    # (the `ideasbugs.button` I18n key).
    attr_accessor :button_label

    # Where the engine is mounted. The widget posts to
    # "#{mount_path}/feedbacks", so keep this in sync with the `mount` line in
    # your routes.
    attr_accessor :mount_path

    # Called with each saved feedback — notify Slack, send an email, open a
    # ticket. Runs inline after save; keep it fast or hand off to a job.
    attr_accessor :on_submit

    def initialize
      @enabled = ->(_request) { true }
      @authorize_admin = ->(_request) { Rails.env.development? }
      @current_user = ->(_request) {}
      @author_label = ->(user) { user.respond_to?(:email) ? user.email : user&.to_s }
      @kinds = %w[bug feature other]
      @sections = []
      @screenshots = true
      @max_screenshots = 3
      @max_screenshot_size = 5 * 1024 * 1024
      @rate_limit = { to: 10, within: 60 }
      @show_button = true
      @button_label = nil
      @mount_path = '/feedback'
      @on_submit = ->(_feedback) {}
    end

    def feedbacks_endpoint
      "#{mount_path.chomp('/')}/feedbacks"
    end

    # Screenshots need Active Storage — both the config switch and the host
    # actually having it loaded.
    def screenshots_enabled?
      screenshots && defined?(::ActiveStorage) ? true : false
    end
  end
end
