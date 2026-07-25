# frozen_string_literal: true

module Ideasbugs
  # One piece of user feedback. Author attribution is optional and stored as
  # loose fields (no foreign key to the host's user table) so the model is
  # portable across apps with different user models.
  class Feedback < ApplicationRecord
    # Hand-rolled instead of an AR enum: `open` would collide with Kernel#open
    # as a scope name, and three statuses don't need the machinery anyway.
    STATUSES = %w[open in_review resolved].freeze

    has_many_attached :screenshots if defined?(::ActiveStorage)

    validates :message, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :kind,
              presence: true,
              inclusion: { in: ->(_) { Ideasbugs.config.kinds.map(&:to_s) } }

    scope :newest_first, -> { order(id: :desc) }

    STATUSES.each do |status|
      define_method(:"#{status}?") { self.status == status }
    end

    def screenshots?
      respond_to?(:screenshots) && screenshots.attached?
    end
  end
end
