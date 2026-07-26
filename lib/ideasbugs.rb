# frozen_string_literal: true

require 'ideasbugs/version'
require 'ideasbugs/configuration'
require 'ideasbugs/widget'
require 'ideasbugs/has_feedback'
require 'ideasbugs/engine'

# In-app product feedback collection for Rails. A drop-in widget lets users
# send bug reports, feature requests, and general feedback (with screenshots)
# from any page; submissions land in your own database, with a minimal built-in
# dashboard to browse and triage them.
module Ideasbugs
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    # Can this request send feedback? Checked on the server for the endpoint
    # and by the helper before rendering the widget.
    def enabled?(request)
      !!config.enabled.call(request)
    end

    # Can this request browse and triage feedback? Checked by every dashboard
    # action.
    def admin?(request)
      !!config.authorize_admin.call(request)
    end

    # The tenant key for this request, or nil for the single global board.
    # Normalized to a string so `where(tenant:)` is consistent whether the
    # resolver returns a GlobalID, an integer id, or a slug; blank becomes nil.
    def tenant(request)
      config.tenant.call(request).presence&.to_s
    end

    # The feedback belonging to a host record, keyed by its GlobalID — the
    # documented tenant convention. Sugar for `Feedback.for_tenant(...)`; the
    # `has_feedback` model concern is built on this.
    def for(record)
      Feedback.for_tenant(tenant_key_for(record))
    end

    private

    # A host record's tenant key: its GlobalID string. Kept in one place so
    # `.for` and `has_feedback` agree — and so a host wiring
    # `config.tenant = ->(r){ Current.org.to_gid.to_s }` lines up with
    # `organization.feedback`.
    def tenant_key_for(record)
      record.respond_to?(:to_gid) ? record.to_gid.to_s : record.to_s
    end
  end
end
