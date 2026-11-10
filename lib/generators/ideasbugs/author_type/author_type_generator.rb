# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../migration_helpers'

module Ideasbugs
  module Generators
    # For apps that installed ideasbugs before 1.4: adds the nullable
    # `author_type` column to ideasbugs_feedbacks, so `author_id` names a
    # record of a known class. A fresh install already gets it. Existing rows
    # keep a nil type; the gem cannot know which class their ids belong to.
    #
    #   bin/rails generate ideasbugs:author_type && bin/rails db:migrate
    class AuthorTypeGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration
      include MigrationHelpers

      source_root File.expand_path('templates', __dir__)

      desc 'Adds the author_type column to ideasbugs_feedbacks (author type upgrade).'

      def create_migration_file
        migration_template 'add_author_type_to_ideasbugs_feedbacks.rb.tt',
                           'db/migrate/add_author_type_to_ideasbugs_feedbacks.rb'
      end

      def post_install
        say "\nauthor_type column queued. Run `rails db:migrate`. Existing rows keep", :green
        say 'a nil type: backfill it yourself if all your authors share one class.'
      end
    end
  end
end
