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
      Ideasbugs::RactorSupport.rate_limit(self, **Ideasbugs.config.rate_limit,
                 only: :create,
                 with: -> { render json: { errors: [t_error(:error_rate_limited)] }, status: :too_many_requests })
    end

    def create
      feedback = Feedback.submit(
        params.require(:feedback).permit(*Feedback::SUBMITTED_ATTRIBUTES),
        author: current_author,
        tenant: current_tenant,
        user_agent: request.user_agent,
        screenshots: params.dig(:feedback, :screenshots)
      )

      if feedback.persisted?
        head :created
      else
        render json: { errors: feedback.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def t_error(key, **)
      Feedback.submission_error(key, **)
    end
  end
end
