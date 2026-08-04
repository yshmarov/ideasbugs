# frozen_string_literal: true

module Ideasbugs
  # Root of the engine's PUBLIC surface: widget.js and the submission endpoint.
  # These stay on a plain ActionController::Base deliberately — someone filing a
  # bug report must not be routed through a host's admin controller, which would
  # demand a staff session for the widget.
  #
  # The dashboard's root is DashboardController, and that is where
  # `config.base_controller_class` applies.
  class ApplicationController < ActionController::Base
    include RequestContext

    protect_from_forgery with: :exception
  end
end
