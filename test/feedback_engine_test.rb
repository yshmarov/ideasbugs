# frozen_string_literal: true

require 'test_helper'

class FeedbackEngineTest < ActiveSupport::TestCase
  test 'has a version number' do
    assert FeedbackEngine::VERSION
  end

  test 'enabled? defaults to true for everyone' do
    assert_equal true, FeedbackEngine.enabled?(Object.new)
  end

  test 'enabled? respects the configured gate' do
    FeedbackEngine.config.enabled = ->(_request) { false }

    assert_equal false, FeedbackEngine.enabled?(Object.new)
  end

  test 'admin? defaults to development only (so: denied in test)' do
    assert_equal false, FeedbackEngine.admin?(Object.new)
  end

  test 'admin? respects the configured gate' do
    FeedbackEngine.config.authorize_admin = ->(_request) { true }

    assert_equal true, FeedbackEngine.admin?(Object.new)
  end
end

class FeedbackEngineConfigurationTest < ActiveSupport::TestCase
  test 'builds the submission endpoint from the mount path' do
    config = FeedbackEngine::Configuration.new

    assert_equal '/feedback/feedbacks', config.feedbacks_endpoint

    config.mount_path = '/support/'

    assert_equal '/support/feedbacks', config.feedbacks_endpoint
  end

  test 'enables screenshots when Active Storage is available' do
    assert_equal true, FeedbackEngine::Configuration.new.screenshots_enabled?
  end

  test 'disables screenshots when switched off' do
    config = FeedbackEngine::Configuration.new
    config.screenshots = false

    assert_equal false, config.screenshots_enabled?
  end
end
