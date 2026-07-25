# frozen_string_literal: true

module Ideasbugs
  class Engine < ::Rails::Engine
    isolate_namespace Ideasbugs

    initializer 'ideasbugs.helper' do
      ActiveSupport.on_load(:action_view) do
        include Ideasbugs::WidgetHelper
      end
    end
  end
end
