# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module Ideasbugs
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      desc 'Installs ideasbugs: config initializer, migration, and engine mount.'

      def create_initializer
        copy_file 'initializer.rb', 'config/initializers/ideasbugs.rb'
      end

      def create_feedbacks_migration
        migration_template 'create_ideasbugs_feedbacks.rb.tt',
                           'db/migrate/create_ideasbugs_feedbacks.rb'
      end

      def mount_engine
        route %(mount_ideasbugs at: "/feedback")
      end

      def post_install
        say "\nideasbugs installed. Run `rails db:migrate`, then add", :green
        say '`<%= ideasbugs_tag %>` before </body> in your layout.'
        say 'Optional: run `bin/rails ideasbugs:seed_demo` for sample feedback.'
        say "Browse submissions at /feedback (development only until you set config.authorize_admin).\n"
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
