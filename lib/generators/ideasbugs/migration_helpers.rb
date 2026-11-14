# frozen_string_literal: true

module Ideasbugs
  module Generators
    # Shared bits every migration-writing generator needs.
    module MigrationHelpers
      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end

      # Follow the host's own key type instead of forcing bigint. An app that
      # keys its models with uuids has a uuid
      # `active_storage_attachments.record_id`, so a bigint table here could
      # never take a screenshot: the foreign key has nowhere to point and
      # `attach` raises NotNullViolation.
      #
      # Same lookup Rails' own Active Storage, Action Text and Action Mailbox
      # migrations do, so a host that set it once gets consistent tables from
      # all of them.
      #
      # Rendered as a `create_table` option rather than a bare value, because a
      # template is expanded at generate time: emitting the method name would
      # put `id: primary_key_type` in the migration, where nothing defines it.
      def primary_key_type_option
        primary_key_type ? ", id: :#{primary_key_type}" : ''
      end

      # The same lookup for a column that points back at a feedback row, so
      # `duplicate_of_id` matches a uuid-keyed table's own id.
      def reference_type_option
        primary_key_type ? ", type: :#{primary_key_type}" : ''
      end

      def primary_key_type
        config = Rails.configuration.generators
        config.options[config.orm][:primary_key_type]
      end

      # Upgrade generators index a table that already holds feedback. On
      # PostgreSQL a plain CREATE INDEX blocks writes until the build finishes,
      # and strong_migrations refuses to run one. A concurrent build cannot run
      # inside a transaction, so those migrations opt out of it. Other adapters
      # have no concurrent build and keep their transaction.
      #
      # Decided at generate time, like the key type, so the migration holds
      # plain code rather than an adapter check.
      def concurrent_indexes?
        ActiveRecord::Base.connection_db_config.adapter.to_s.include?('postg')
      end

      def concurrent_index_option
        concurrent_indexes? ? ', algorithm: :concurrently' : ''
      end
    end
  end
end
