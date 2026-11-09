# frozen_string_literal: true

require 'uri'

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
      scope status, -> { where(status:) }
    end

    # A duplicate is a judgment, not a merge: the row keeps its own words,
    # author and screenshots, and points at the original asking for the same
    # thing. Always one level deep, so nothing walks a chain. Installs from
    # before 1.3 lack the column until they run `ideasbugs:duplicates`, and
    # everything below stays inert until then; hence no `dependent:` here.
    belongs_to :duplicate_of, class_name: 'Ideasbugs::Feedback', optional: true, inverse_of: :duplicates
    has_many :duplicates, class_name: 'Ideasbugs::Feedback', foreign_key: :duplicate_of_id,
                          inverse_of: :duplicate_of

    validate :duplicate_of_an_original, if: -> { self.class.tracks_duplicates? && duplicate_of_id_changed? }
    before_destroy :release_duplicates

    # What the queue lists: everything that is not a duplicate of something else.
    # `klass.`, not a bare call: relation delegation caches the method name on
    # the class, which a non-main Ractor may not write.
    scope :originals, -> { klass.tracks_duplicates? ? where(duplicate_of_id: nil) : all }

    def self.tracks_duplicates?
      column_names.include?('duplicate_of_id')
    end

    SUBMITTED_ATTRIBUTES = %i[kind section message page_url].freeze

    # Files feedback the way the widget does: privacy-filtered page URL, author
    # attribution, screenshot limits, then the host's on_submit hook. A host
    # with its own API calls this rather than re-implementing those rules.
    # Returns the feedback; check persisted? and errors.
    def self.submit(attributes, author: nil, tenant: nil, user_agent: nil, screenshots: nil)
      feedback = new(attributes.to_h.symbolize_keys.slice(*SUBMITTED_ATTRIBUTES))
      feedback.page_url = clean_page_url(feedback.page_url)
      feedback.user_agent = user_agent
      feedback.tenant = tenant.presence&.to_s
      feedback.attribute_to(author)

      if (error = feedback.attach_screenshots(Array(screenshots).compact_blank))
        feedback.errors.add(:base, error)
      elsif feedback.save
        feedback.notify_host
      end
      feedback
    end

    # Browser URLs can carry password-reset tokens, signed ids, and campaign
    # details in their query or fragment. Store only a bounded HTTP(S) location
    # without credentials before it reaches the feedback table.
    def self.clean_page_url(value)
      raw = value.to_s
      return if raw.blank? || raw.length > 2_048

      uri = URI.parse(raw)
      return unless %w[http https].include?(uri.scheme&.downcase)
      return if uri.host.blank? || uri.userinfo.present?

      uri.query = nil
      uri.fragment = nil
      uri.to_s.first(255)
    rescue URI::InvalidURIError
      nil
    end

    def self.submission_error(key, **args)
      defaults = {
        error_save: 'Could not send feedback. Please try again.',
        error_too_many: 'Too many screenshots (max %{count}).',
        error_too_large: 'A screenshot is too large (max %{size} MB).',
        error_rate_limited: 'Too many submissions. Please wait a moment and try again.'
      }
      I18n.t(key, scope: :ideasbugs, default: defaults[key], **args)
    end

    def open? = status == 'open'
    def in_review? = status == 'in_review'
    def resolved? = status == 'resolved'

    def screenshots?
      respond_to?(:screenshots) && screenshots.attached?
    end

    def duplicate?
      self.class.tracks_duplicates? && duplicate_of_id.present?
    end

    # Files this feedback under `original` as asking for the same thing. The
    # link stays one level deep: a duplicate of a duplicate points at its
    # original, this row's own duplicates move along with it, and marking an
    # original as a duplicate of one of its own duplicates swaps the two.
    def mark_duplicate_of!(original)
      original = original.duplicate_of if original.duplicate_of_id && original.duplicate_of_id != id

      transaction do
        # Moving links fires nothing, and must not trip validations that a row
        # filed under an older config would fail today.
        duplicates.where.not(id: original.id).update_all(duplicate_of_id: original.id, updated_at: Time.current)
        original.update_column(:duplicate_of_id, nil) if original.duplicate_of_id == id
        update!(duplicate_of: original)
      end
    end

    def unmark_duplicate!
      update!(duplicate_of: nil)
    end

    def attribute_to(author)
      return unless author

      self.author_id = author.id.to_s if author.respond_to?(:id)
      self.author_label = Ideasbugs.config.author_label.call(author)
    end

    # Attaches uploads, or returns the error that rejects them. No screenshots
    # at all is fine.
    def attach_screenshots(files)
      return if files.empty?

      key, args = screenshot_error(files)
      return self.class.submission_error(key, **args.to_h) if key

      screenshots.attach(files)
      nil
    end

    # The host's hook must never turn a saved submission into a failure: the
    # feedback is in the database; notification failures are the host's logs'
    # problem.
    def notify_host
      Ideasbugs.config.on_submit.call(self)
    rescue StandardError => e
      Rails.logger.error("ideasbugs: on_submit hook raised #{e.class}: #{e.message}")
    end

    private

    def duplicate_of_an_original
      return if duplicate_of_id.nil?

      original = duplicate_of
      if original.nil? || original.id == id
        errors.add(:duplicate_of, 'must be another feedback')
      elsif original.tenant != tenant
        errors.add(:duplicate_of, 'must be on the same board')
      elsif original.duplicate_of_id
        errors.add(:duplicate_of, 'is itself a duplicate')
      elsif persisted? && duplicates.exists?
        errors.add(:base, 'Feedback with duplicates of its own cannot be a duplicate')
      end
    end

    # Deleting an original puts its duplicates back in the queue.
    def release_duplicates
      return unless self.class.tracks_duplicates?

      duplicates.update_all(duplicate_of_id: nil, updated_at: Time.current)
    end

    def screenshot_error(files)
      config = Ideasbugs.config
      return [:error_save] unless config.screenshots_enabled?
      return [:error_too_many, { count: config.max_screenshots }] if files.size > config.max_screenshots

      max_size = config.max_screenshot_size
      return [:error_too_large, { size: max_size / (1024 * 1024) }] if files.any? { |f| f.size > max_size }

      [:error_save] unless files.all? { |f| f.content_type.to_s.start_with?('image/') }
    end
  end
end
