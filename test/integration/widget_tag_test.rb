# frozen_string_literal: true

require 'test_helper'

class WidgetTagTest < ActionDispatch::IntegrationTest
  test 'renders the config block and the nonced widget script' do
    get '/sample'

    assert_includes response.body, 'data-feedback-engine-config'
    assert_includes response.body, '<script data-feedback-engine-widget nonce="testnonce">'
    assert_includes response.body, '"endpoint":"/feedback/feedbacks"'
  end

  test 'renders nothing when feedback is disabled for the request' do
    FeedbackEngine.config.enabled = ->(_request) { false }

    get '/sample'

    assert_not_includes response.body, 'data-feedback-engine-config'
    assert_not_includes response.body, 'data-feedback-engine-widget'
  end
end
