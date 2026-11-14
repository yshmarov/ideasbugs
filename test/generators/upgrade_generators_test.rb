# frozen_string_literal: true

require 'test_helper'
require 'rails/generators/test_case'
require 'generators/ideasbugs/tenant/tenant_generator'
require 'generators/ideasbugs/duplicates/duplicates_generator'

# Upgrade generators index a table that already holds feedback, so on
# PostgreSQL they must build concurrently (outside a transaction), or they
# lock writes and strong_migrations refuses them. Other adapters keep the plain
# migration. The dummy app is SQLite, so the PostgreSQL shape is forced per run.
module UpgradeGeneratorAssertions
  private

  def run_generator_on(adapter)
    instance = generator
    instance.define_singleton_method(:concurrent_indexes?) { adapter == :postgresql }
    quietly { instance.invoke_all }
  end

  def assert_ruby(path)
    assert RubyVM::InstructionSequence.compile(File.read(path)), "#{path} is not valid Ruby"
  end
end

class TenantGeneratorTest < Rails::Generators::TestCase
  include UpgradeGeneratorAssertions

  tests Ideasbugs::Generators::TenantGenerator
  destination File.expand_path('../tmp/generator', __dir__)
  setup :prepare_destination

  test 'builds the tenant index concurrently on PostgreSQL' do
    run_generator_on :postgresql

    assert_migration 'db/migrate/add_tenant_to_ideasbugs_feedbacks.rb' do |migration|
      assert_match 'disable_ddl_transaction!', migration
      assert_match 'add_index :ideasbugs_feedbacks, %i[tenant status], algorithm: :concurrently', migration
    end
    assert_ruby Dir[File.join(destination_root, 'db/migrate/*_add_tenant_to_ideasbugs_feedbacks.rb')].sole
  end

  test 'keeps a plain transactional migration elsewhere' do
    run_generator_on :sqlite3

    assert_migration 'db/migrate/add_tenant_to_ideasbugs_feedbacks.rb' do |migration|
      refute_match 'disable_ddl_transaction!', migration
      refute_match 'concurrently', migration
      assert_match 'add_index :ideasbugs_feedbacks, %i[tenant status]', migration
    end
    assert_ruby Dir[File.join(destination_root, 'db/migrate/*_add_tenant_to_ideasbugs_feedbacks.rb')].sole
  end
end

class DuplicatesGeneratorTest < Rails::Generators::TestCase
  include UpgradeGeneratorAssertions

  tests Ideasbugs::Generators::DuplicatesGenerator
  destination File.expand_path('../tmp/generator', __dir__)
  setup :prepare_destination

  test 'builds the duplicate_of index concurrently on PostgreSQL' do
    run_generator_on :postgresql

    assert_migration 'db/migrate/add_duplicate_of_to_ideasbugs_feedbacks.rb' do |migration|
      assert_match 'disable_ddl_transaction!', migration
      assert_match 'index: { algorithm: :concurrently }', migration
    end
    assert_ruby Dir[File.join(destination_root, 'db/migrate/*_add_duplicate_of_to_ideasbugs_feedbacks.rb')].sole
  end

  test 'keeps a plain transactional migration elsewhere' do
    run_generator_on :sqlite3

    assert_migration 'db/migrate/add_duplicate_of_to_ideasbugs_feedbacks.rb' do |migration|
      refute_match 'disable_ddl_transaction!', migration
      refute_match 'concurrently', migration
      assert_match 'index: true', migration
    end
    assert_ruby Dir[File.join(destination_root, 'db/migrate/*_add_duplicate_of_to_ideasbugs_feedbacks.rb')].sole
  end

  test 'follows the real adapter when nothing forces it' do
    quietly { run_generator }

    assert_migration 'db/migrate/add_duplicate_of_to_ideasbugs_feedbacks.rb' do |migration|
      refute_match 'concurrently', migration
    end
  end
end
