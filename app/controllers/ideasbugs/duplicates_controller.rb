# frozen_string_literal: true

module Ideasbugs
  # Files a feedback under another one asking for the same thing, or takes it
  # back out. Both ends resolve through the tenant scope, so a duplicate can
  # never point across boards.
  class DuplicatesController < DashboardController
    before_action -> { head :not_found unless Feedback.tracks_duplicates? }
    before_action -> { @feedback = tenant_scope.find(params[:feedback_id]) }

    def create
      original = tenant_scope.find_by(id: params[:original_id].to_s.delete_prefix('#').strip)
      unless original
        return refuse(t('ideasbugs.dashboard.duplicate_not_found', default: 'No feedback with that number.'))
      end

      @feedback.mark_duplicate_of!(original)
      original = @feedback.duplicate_of
      redirect_to feedbacks_path(status: original.status, feedback_id: original.id), status: :see_other
    rescue ActiveRecord::RecordInvalid => e
      refuse(e.record.errors.full_messages.to_sentence)
    end

    def destroy
      @feedback.unmark_duplicate!
      redirect_to feedbacks_path(status: @feedback.status, feedback_id: @feedback.id), status: :see_other
    end

    private

    def refuse(message)
      redirect_back fallback_location: feedbacks_path(feedback_id: @feedback.id), alert: message, status: :see_other
    end
  end
end
