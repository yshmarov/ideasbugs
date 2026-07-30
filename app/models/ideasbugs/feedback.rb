# frozen_string_literal: true

module Ideasbugs
  # One piece of user feedback. Author attribution is optional and stored as
  # loose fields (no foreign key to the host's user table) so the model is
  # portable across apps with different user models.
  class Feedback < ApplicationRecord
    # Hand-rolled instead of an AR enum: `open` would collide with Kernel#open
    # as a scope name, and three statuses don't need the machinery anyway.
    STATUSES = %w[open in_review resolved].freeze

    if defined?(::ActiveStorage)
      # Read at class load, after the host's initializer has run. nil falls
      # through to Active Storage's environment default service.
      has_many_attached :screenshots, service: Ideasbugs.config.storage_service
    end

    validates :message, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :kind,
              presence: true,
              inclusion: { in: ->(_) { Ideasbugs.config.kinds.map(&:to_s) } }

    # Multi-tenancy: everything is scoped to an opaque tenant key (nil = the
    # single global board). Loose-coupled like author_id — a string, no FK
    # into the host's tables. See Ideasbugs.config.tenant.
    scope :for_tenant, ->(tenant) { where(tenant: tenant.presence) }

    scope :newest_first, -> { order(id: :desc) }

    STATUSES.each do |status|
      define_method(:"#{status}?") { self.status == status }
    end

    def screenshots?
      respond_to?(:screenshots) && screenshots.attached?
    end
  end
end
