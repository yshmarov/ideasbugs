# frozen_string_literal: true

require 'test_helper'

class IdeasbugsTest < ActiveSupport::TestCase
  test 'has a version number' do
    assert Ideasbugs::VERSION
  end

  test 'enabled? defaults to true for everyone' do
    assert_equal true, Ideasbugs.enabled?(Object.new)
  end

  test 'enabled? respects the configured gate' do
    Ideasbugs.config.enabled = ->(_request) { false }

    assert_equal false, Ideasbugs.enabled?(Object.new)
  end

  test 'admin? defaults to development only (so: denied in test)' do
    assert_equal false, Ideasbugs.admin?(Object.new)
  end

  test 'admin? respects the configured gate' do
    Ideasbugs.config.authorize_admin = ->(_request) { true }

    assert_equal true, Ideasbugs.admin?(Object.new)
  end

  test 'mount_ideasbugs keeps config.mount_path in sync with the route' do
    routes = ActionDispatch::Routing::RouteSet.new

    routes.draw do
      mount_ideasbugs at: '/support'
    end

    assert_equal '/support', Ideasbugs.config.mount_path
  end
end

class IdeasbugsConfigurationTest < ActiveSupport::TestCase
  test 'builds the submission endpoint from the mount path' do
    config = Ideasbugs::Configuration.new

    assert_equal '/feedback/feedbacks', config.feedbacks_endpoint

    config.mount_path = '/support/'

    assert_equal '/support/feedbacks', config.feedbacks_endpoint
  end

  test 'enables screenshots when Active Storage is available' do
    assert_equal true, Ideasbugs::Configuration.new.screenshots_enabled?
  end

  test 'disables screenshots when switched off' do
    config = Ideasbugs::Configuration.new
    config.screenshots = false

    assert_equal false, config.screenshots_enabled?
  end
end
