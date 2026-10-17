# frozen_string_literal: true

module Ideasbugs
  class Engine < ::Rails::Engine
    initializer 'ideasbugs.ractor_middleware' do |app|
      app.middleware.insert_before 0, RactorSupport::Middleware
    end

    isolate_namespace Ideasbugs

    initializer 'ideasbugs.ractorize', before: 'action_controller.ractorize' do
      if Rails::Application.method_defined?(:ractorize!)
        Engine.routes.singleton_class.prepend(RactorSupport::MountedRoutes)
      end
      ActiveSupport.on_load(:before_ractorize) { Ideasbugs::RactorSupport.prepare! }
    end

    rake_tasks do
      load File.expand_path('../tasks/ideasbugs_tasks.rake', __dir__)
    end

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
