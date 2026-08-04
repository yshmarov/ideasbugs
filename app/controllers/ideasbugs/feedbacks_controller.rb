# frozen_string_literal: true

module Ideasbugs
  class FeedbacksController < DashboardController
    PER_PAGE = 50

    # The widget posts here; everything else is the triage dashboard.
    before_action :set_feedback, only: %i[show update destroy]

    def index
      @status = Feedback::STATUSES.include?(params[:status]) ? params[:status] : 'open'
      @kind = Ideasbugs.config.kinds.map(&:to_s).include?(params[:kind]) ? params[:kind] : nil
      @query = params[:q].to_s.strip.presence
      @counts = tenant_scope.group(:status).count

      scope = tenant_scope.where(status: @status)
      scope = scope.where(kind: @kind) if @kind
      scope = search(scope) if @query
      @page = [params[:page].to_i, 1].max
      @feedbacks = scope.newest_first.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @more = @feedbacks.size > PER_PAGE
      @feedbacks = @feedbacks.first(PER_PAGE)

      @selected_feedback = tenant_scope.find_by(id: params[:feedback_id]) if params[:feedback_id].present?

      # Only surface the Section column when it can carry information: the host
      # configured sections, or some record already has one (e.g. sections were
      # configured historically). Otherwise it's a permanently blank column.
      @show_section = Ideasbugs.config.sections.any? || @feedbacks.any? { |f| f.section.present? }
    end

    def show; end

    def update
      @feedback.update!(params.require(:feedback).permit(:status))
      redirect_back fallback_location: feedback_path(@feedback), status: :see_other
    end

    def destroy
      @feedback.destroy!
      redirect_to root_path, status: :see_other
    end

    private

    def set_feedback
      @feedback = tenant_scope.find(params[:id])
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
  end
end
