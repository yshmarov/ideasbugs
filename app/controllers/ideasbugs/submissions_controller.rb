# frozen_string_literal: true

module Ideasbugs
  # The widget's write endpoint: POST /feedbacks.
  #
  # Public, so it stays on ApplicationController and never inherits a host's
  # admin base controller — someone filing a bug report must not be asked for a
  # staff session. The triage actions live in FeedbacksController, which does
  # inherit it.
  class SubmissionsController < ApplicationController
    before_action :require_enabled

    # Throttle the public endpoint per IP so one user or bot can't flood the
    # table (each submission may carry megabytes of screenshots). Uses the
    # rate limiter built into Rails 7.2+ (backed by Rails.cache); on Rails 7.1
    # this is a no-op. Tune or disable via config.rate_limit — read once at
    # boot, after the host's initializer.
    if respond_to?(:rate_limit) && Ideasbugs.config.rate_limit
      rate_limit(**Ideasbugs.config.rate_limit,
                 only: :create,
                 with: -> { render json: { errors: [t_error(:error_rate_limited)] }, status: :too_many_requests })
    end

    def create
      feedback = Feedback.new(feedback_params)
      feedback.user_agent = request.user_agent
      feedback.tenant = current_tenant
      attribute_author(feedback)

      error = attach_screenshots(feedback)
      return render json: { errors: [error] }, status: :unprocessable_entity if error

      if feedback.save
        notify_host(feedback)
        head :created
      else
        render json: { errors: feedback.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    # The host's hook must never turn a saved submission into a 500 — the
    # feedback is in the database; notification failures are the host's logs'
    # problem.
    def notify_host(feedback)
      Ideasbugs.config.on_submit.call(feedback)
    rescue StandardError => e
      Rails.logger.error("ideasbugs: on_submit hook raised #{e.class}: #{e.message}")
    end

    def feedback_params
      params.require(:feedback).permit(:kind, :section, :message, :page_url)
    end

    def attribute_author(feedback)
      author = current_author
      return unless author

      feedback.author_id = author.id.to_s if author.respond_to?(:id)
      feedback.author_label = Ideasbugs.config.author_label.call(author)
    end

    # Validates and attaches uploads. Returns an error message, or nil when
    # everything (including "no screenshots at all") is fine.
    def attach_screenshots(feedback)
      files = Array(params.dig(:feedback, :screenshots)).reject(&:blank?)
      return nil if files.empty?
      return t_error(:error_save) unless Ideasbugs.config.screenshots_enabled?
      return t_error(:error_too_many, count: Ideasbugs.config.max_screenshots) if too_many?(files)
      return t_error(:error_too_large, size: max_size_mb) if files.any? { |f| f.size > max_size }
      return t_error(:error_save) unless files.all? { |f| f.content_type.to_s.start_with?('image/') }

      feedback.screenshots.attach(files)
      nil
    end

    def too_many?(files)
      files.size > Ideasbugs.config.max_screenshots
    end

    def max_size_mb
      max_size / (1024 * 1024)
    end

    def max_size
      Ideasbugs.config.max_screenshot_size
    end

    def t_error(key, **args)
      defaults = {
        error_save: 'Could not send feedback. Please try again.',
        error_too_many: 'Too many screenshots (max %{count}).',
        error_too_large: 'A screenshot is too large (max %{size} MB).',
        error_rate_limited: 'Too many submissions. Please wait a moment and try again.'
      }
      I18n.t(key, scope: :ideasbugs, default: defaults[key], **args)
    end
  end
end
