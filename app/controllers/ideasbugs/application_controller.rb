# frozen_string_literal: true

module Ideasbugs
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

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
  end
end
