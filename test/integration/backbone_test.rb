# frozen_string_literal: true

require 'test_helper'
require 'rails/generators'
require 'generators/ideasbugs/install/install_generator'

# The invariants shared across this family of engines. Each one exists because
# breaking it produced a real failure in a host app, and each was invisible to
# the rest of the suite.
class BackboneTest < ActionDispatch::IntegrationTest
  # 1. A host that replaces the layout must still get the dashboard's assets.
  #    They used to be declared in the gem's own layout, so `admin_layout` (and
  #    now base_controller_class) silently dropped the stylesheet and script:
  #    unstyled dashboard, dead client-side behaviour.
  test 'every dashboard page carries its own assets, under any layout' do
    authorize_admin!
    feedback = Ideasbugs::Feedback.create!(kind: 'bug', message: 'It broke')

    [nil, 'host_admin'].each do |layout|
      Ideasbugs.config.admin_layout = layout if layout
      ['/feedback', "/feedback/feedbacks/#{feedback.id}"].each do |path|
        get path

        assert_response :ok, "#{path} (layout #{layout.inspect}) did not render"
        assert_includes response.body, 'dashboard.css?v=', "#{path} is missing the stylesheet"
        assert_includes response.body, 'class="ib-dashboard"', "#{path} is missing the scoping wrapper"
      end
    end
  end

  # 2. Everything a host already styles. A bare `body`/`a`/`table`/`*` rule, or
  #    an unprefixed `.card`/`.container`, restyles the host's own chrome the
  #    moment its admin loads this file.
  test 'the stylesheet claims no selector outside its own namespace' do
    get '/feedback/dashboard.css'

    top_level_selectors(response.body).each do |part|
      assert part.start_with?('.ib-', ':root'),
             "top-level selector #{part.inspect} is not namespaced to the dashboard"
    end
  end

  # 3. Custom properties collide BOTH ways: a host defining --bg would recolour
  #    the dashboard, and the dashboard would recolour the host.
  test 'the stylesheet prefixes every custom property' do
    get '/feedback/dashboard.css'

    response.body.scan(/(--[a-z0-9-]+)\s*:/).flatten.uniq.each do |property|
      assert property.start_with?('--ib-'), "custom property #{property} could collide with a host's"
    end
  end

  # 4. base_controller_class reparents the DASHBOARD only. If a public endpoint
  #    shared a controller with the dashboard, pointing this at a host's admin
  #    controller would demand a staff session from an ordinary visitor.
  test 'only the dashboard hangs off the configured base controller' do
    assert_equal Ideasbugs.base_controller, Ideasbugs::DashboardController.superclass
    assert_equal ActionController::Base, Ideasbugs::ApplicationController.superclass

    [Ideasbugs::WidgetsController, Ideasbugs::SubmissionsController].each do |controller|
      assert_equal Ideasbugs::ApplicationController, controller.superclass,
                   "#{controller} must not inherit the host's base controller"
    end
    [Ideasbugs::FeedbacksController, Ideasbugs::ScreenshotsController].each do |controller|
      assert_equal Ideasbugs::DashboardController, controller.superclass
    end
  end

  test 'base_controller_class resolves a host class lazily, by name' do
    assert_equal 'ActionController::Base', Ideasbugs.config.base_controller_class
    Ideasbugs.config.base_controller_class = 'HostAdminBaseController'

    assert_equal HostAdminBaseController, Ideasbugs.base_controller
  end

  # 5. A uuid-keyed host has a uuid active_storage_attachments.record_id, so a
  #    bigint table here can never hold a screenshot: `attach` raises
  #    NotNullViolation. Record routes must accept a non-integer id to match.
  test 'record routes accept a non-integer primary key' do
    uuid = '0f8fad5b-d9cb-469f-a165-70867728950e'

    assert_equal({ controller: 'ideasbugs/feedbacks', action: 'show', id: uuid },
                 Ideasbugs::Engine.routes.recognize_path("/feedbacks/#{uuid}", method: :get))
  end

  # The widget posts to /feedbacks. That has to keep working no matter what the
  # dashboard inherits, which is why it routes to a different controller.
  test 'POST and GET on the collection split across the two roots' do
    engine = Ideasbugs::Engine.routes

    assert_equal 'ideasbugs/submissions', engine.recognize_path('/feedbacks', method: :post)[:controller]
    assert_equal 'ideasbugs/feedbacks', engine.recognize_path('/feedbacks', method: :get)[:controller]
    assert_equal 'ideasbugs/widgets', engine.recognize_path('/dashboard.css', method: :get)[:controller]
  end

  private

  def authorize_admin!
    Ideasbugs.config.authorize_admin = ->(_request) { true }
  end

  # Selectors at nesting depth 0 — the ones that can reach a host's markup.
  # Anything nested inside the wrapper is already scoped, and at-rules are
  # descended into rather than treated as selectors.
  def top_level_selectors(css)
    css = css.gsub(%r{/\*.*?\*/}m, '')
    selectors = []
    buffer = +''
    depth = 0

    css.each_char do |char|
      case char
      when '{'
        head = buffer.strip
        selectors.concat(head.split(',').map(&:strip).reject(&:empty?)) if depth.zero? && !head.start_with?('@')
        depth += 1 unless head.start_with?('@')
        buffer = +''
      when '}'
        depth -= 1 if depth.positive?
        buffer = +''
      when ';'
        buffer = +''
      else
        buffer << char
      end
    end

    selectors
  end
end

# 6. A template is expanded at generate time, so the id option has to be the
#    resolved value, and no index may duplicate a leftmost prefix of another.
class BackboneGeneratorTest < Rails::Generators::TestCase
  tests Ideasbugs::Generators::InstallGenerator
  destination File.expand_path('../tmp/backbone', __dir__)
  setup :prepare_destination
  setup :write_routes

  test 'the table follows the host generators primary_key_type' do
    with_primary_key_type(:uuid) do
      run_generator

      assert_migration 'db/migrate/create_ideasbugs_feedbacks.rb' do |migration|
        assert_match 'create_table :ideasbugs_feedbacks, id: :uuid', migration
        refute_match 'primary_key_type', migration
      end
    end
  end

  test 'the table takes no id option when the host sets nothing' do
    with_primary_key_type(nil) do
      run_generator

      assert_migration 'db/migrate/create_ideasbugs_feedbacks.rb' do |migration|
        assert_match 'create_table :ideasbugs_feedbacks do |t|', migration
      end
    end
  end

  # A B-tree serves any leftmost prefix, so a single-column index that leads a
  # composite one earns nothing and only costs write time and disk.
  test 'no index duplicates a leftmost prefix of another' do
    run_generator

    assert_migration 'db/migrate/create_ideasbugs_feedbacks.rb' do |migration|
      indexes = migration.scan(/add_index :(\w+), (?:%i\[([\w\s]+)\]|:(\w+))/).map do |table, composite, single|
        [table, composite ? composite.split : [single]]
      end

      indexes.each do |table, columns|
        others = indexes.reject { |t, c| t != table || c == columns }
        redundant = others.find { |_, other| other.first(columns.length) == columns }
        assert_nil redundant, "#{table} index on #{columns.inspect} is a prefix of #{redundant&.last.inspect}"
      end
    end
  end

  private

  # `route` needs somewhere to inject; without it the generator only warns.
  def write_routes
    FileUtils.mkdir_p(File.join(destination_root, 'config'))
    File.write(File.join(destination_root, 'config/routes.rb'), "Rails.application.routes.draw do\nend\n")
  end

  def with_primary_key_type(type)
    config = Rails.configuration.generators
    previous = config.options[config.orm][:primary_key_type]
    config.options[config.orm][:primary_key_type] = type
    yield
  ensure
    config.options[config.orm][:primary_key_type] = previous
  end
end
