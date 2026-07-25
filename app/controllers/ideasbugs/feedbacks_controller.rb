# frozen_string_literal: true

module Ideasbugs
  class FeedbacksController < ApplicationController
    PER_PAGE = 50

    layout 'ideasbugs/application', except: :create

    # The widget posts here; everything else is the triage dashboard.
    before_action :require_enabled, only: :create
    before_action :require_admin, except: :create
    before_action :set_feedback, only: %i[show update destroy]

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

    def index
      @status = Feedback::STATUSES.include?(params[:status]) ? params[:status] : 'open'
      @kind = Ideasbugs.config.kinds.map(&:to_s).include?(params[:kind]) ? params[:kind] : nil
      @query = params[:q].to_s.strip.presence
      @counts = Feedback.group(:status).count

      scope = Feedback.where(status: @status)
      scope = scope.where(kind: @kind) if @kind
      scope = search(scope) if @query
      @page = [params[:page].to_i, 1].max
      @feedbacks = scope.newest_first.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @more = @feedbacks.size > PER_PAGE
      @feedbacks = @feedbacks.first(PER_PAGE)

      # Only surface the Section column when it can carry information: the host
      # configured sections, or some record already has one (e.g. sections were
      # configured historically). Otherwise it's a permanently blank column.
      @show_section = Ideasbugs.config.sections.any? || @feedbacks.any? { |f| f.section.present? }
    end

    def show; end

    def create
      feedback = Feedback.new(feedback_params)
      feedback.user_agent = request.user_agent
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

    def update
      @feedback.update!(params.require(:feedback).permit(:status))
      redirect_back fallback_location: feedback_path(@feedback), status: :see_other
    end

    def destroy
      @feedback.destroy!
      redirect_to root_path, status: :see_other
    end

    private

    def require_enabled
      head :forbidden unless Ideasbugs.enabled?(request)
    end

    # Server-side gate for the dashboard. Default: development only.
    def require_admin
      return if Ideasbugs.admin?(request)

      render plain: 'Forbidden. Set Ideasbugs.config.authorize_admin to grant access.',
             status: :forbidden
    end

    def set_feedback
      @feedback = Feedback.find(params[:id])
    end

    # Case-insensitive match on the free-text columns. LOWER() keeps it
    # portable across SQLite/PostgreSQL/MySQL, and the explicit ESCAPE makes
    # the sanitized backslash escapes work on SQLite, which has no default
    # LIKE escape character.
    def search(scope)
      pattern = "%#{Feedback.sanitize_sql_like(@query.downcase)}%"
      scope.where(
        "LOWER(message) LIKE :q ESCAPE '\\' OR LOWER(COALESCE(author_label, '')) LIKE :q ESCAPE '\\' " \
        "OR LOWER(COALESCE(section, '')) LIKE :q ESCAPE '\\'",
        q: pattern
      )
    end

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

    def max_size
      Ideasbugs.config.max_screenshot_size
    end

    def max_size_mb
      max_size / (1024 * 1024)
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
