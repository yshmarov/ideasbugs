# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../migration_helpers'

module Ideasbugs
  module Generators
    # For apps that installed ideasbugs before 1.3: adds the nullable
    # `duplicate_of_id` column (and its index) to ideasbugs_feedbacks. A fresh
    # install already gets it. Additive: existing rows are originals, and the
    # dashboard offers duplicate marking once the column exists.
    #
    #   bin/rails generate ideasbugs:duplicates && bin/rails db:migrate
    class DuplicatesGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration
      include MigrationHelpers

      source_root File.expand_path('templates', __dir__)

      desc 'Adds the duplicate_of column to ideasbugs_feedbacks (duplicates upgrade).'

      def create_migration_file
        migration_template 'add_duplicate_of_to_ideasbugs_feedbacks.rb.tt',
                           'db/migrate/add_duplicate_of_to_ideasbugs_feedbacks.rb'
      end

      def post_install
        say "\nduplicate_of column queued. Run `rails db:migrate`, then mark", :green
        say 'duplicates from any feedback in the dashboard.'
      end
    end
  end
end
