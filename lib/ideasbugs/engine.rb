# frozen_string_literal: true

module Ideasbugs
  class Engine < ::Rails::Engine
    isolate_namespace Ideasbugs

    initializer 'ideasbugs.helper' do
      ActiveSupport.on_load(:action_view) do
        include Ideasbugs::WidgetHelper
      end
    end

    # Make the optional `has_feedback` model macro available on every Active
    # Record model, without requiring the host to include anything.
    initializer 'ideasbugs.model' do
      ActiveSupport.on_load(:active_record) do
        extend Ideasbugs::HasFeedback
      end
    end

    initializer 'ideasbugs.routing' do
      ActionDispatch::Routing::Mapper.include(Module.new do
        def mount_ideasbugs(at: Ideasbugs.config.mount_path, **options)
          Ideasbugs.config.mount_path = at
          mount Ideasbugs::Engine, at:, **options
        end
      end)
    end
  end
end
