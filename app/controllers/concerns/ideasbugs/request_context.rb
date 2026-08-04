# frozen_string_literal: true

module Ideasbugs
  # Who is asking, which tenant they are in, and the gates that answer both.
  #
  # A concern rather than inherited behaviour because the engine has two
  # controller roots: the public endpoints hang off ActionController::Base, and
  # the dashboard hangs off whatever the host set as `base_controller_class`.
  module RequestContext
    extend ActiveSupport::Concern

    private

    def ideasbugs_admin_layout
      Ideasbugs.config.admin_layout
    end

    def current_author
      return @current_author if defined?(@current_author)

      @current_author = Ideasbugs.config.current_user.call(request)
    end

    # The tenant for this request (nil = the single global board). Every read
    # and write scopes to it, so a resolved-tenant admin only ever sees and
    # writes their own tenant's feedback.
    def current_tenant
      return @current_tenant if defined?(@current_tenant)

      @current_tenant = Ideasbugs.tenant(request)
    end

    def require_enabled
      head :forbidden unless Ideasbugs.enabled?(request)
    end

    # Server-side gate for the dashboard. Default: development only.
    def require_admin
      return if Ideasbugs.admin?(request)

      render plain: 'Forbidden. Set Ideasbugs.config.authorize_admin to grant access.',
             status: :forbidden
    end

    # Every dashboard query starts here, so an admin can only ever load,
    # triage, or delete feedback in their own tenant — a cross-tenant id 404s.
    def tenant_scope
      Feedback.for_tenant(current_tenant)
    end
  end
end
