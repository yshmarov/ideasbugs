# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'
require_relative '../migration_helpers'

module Ideasbugs
  module Generators
    # For apps that installed ideasbugs before multi-tenancy: adds the nullable
    # `tenant` column (and its index) to ideasbugs_feedbacks. A fresh install
    # already gets it via the install generator — run this one only to upgrade
    # an existing install. Additive and safe: existing rows keep a nil tenant
    # (the single global board), so nothing changes until you set config.tenant.
    #
    #   bin/rails generate ideasbugs:tenant && bin/rails db:migrate
    class TenantGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration
      include MigrationHelpers

      source_root File.expand_path('templates', __dir__)

      desc 'Adds the tenant column to ideasbugs_feedbacks (multi-tenancy upgrade).'

      def create_migration_file
        migration_template 'add_tenant_to_ideasbugs_feedbacks.rb.tt',
                           'db/migrate/add_tenant_to_ideasbugs_feedbacks.rb'
      end

      def post_install
        say "\ntenant column queued. Run `rails db:migrate`, then set", :green
        say 'config.tenant in config/initializers/ideasbugs.rb to scope per tenant.'
      end
    end
  end
end
