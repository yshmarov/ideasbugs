# frozen_string_literal: true

require 'test_helper'

class WidgetTagTest < ActionDispatch::IntegrationTest
  test 'renders the config block and the fingerprinted, nonced widget script' do
    get '/sample'

    src = "/feedback/widget.js?v=#{Ideasbugs::Widget.fingerprint}"

    assert_includes response.body, 'data-ideasbugs-config'
    assert_includes response.body, %(<script src="#{src}" defer nonce="testnonce" data-ideasbugs-widget></script>)
    assert_includes response.body, '"endpoint":"/feedback/feedbacks"'
  end

  test 'serves the widget code as same-origin JavaScript with an ETag' do
    get '/feedback/widget.js'

    assert_response :ok
    assert_equal 'text/javascript', response.media_type
    assert_includes response.body, 'ideasbugs widget'
    assert response.headers['ETag'].present?
  end

  test 'the fingerprinted URL is immutable: public, cached for a year' do
    get "/feedback/widget.js?v=#{Ideasbugs::Widget.fingerprint}"

    assert_response :ok
    assert_includes response.headers['Cache-Control'], 'public'
    assert_includes response.headers['Cache-Control'], 'max-age=31556952'
  end

  test 'a stale or missing fingerprint only revalidates, never long-caches' do
    get '/feedback/widget.js?v=stale'

    assert_response :ok
    assert_not_includes response.headers['Cache-Control'], 'public'
    assert_includes response.headers['Cache-Control'], 'must-revalidate'
  end

  test 'renders nothing when feedback is disabled for the request' do
    Ideasbugs.config.enabled = ->(_request) { false }

    get '/sample'

    assert_not_includes response.body, 'data-ideasbugs-config'
    assert_not_includes response.body, 'data-ideasbugs-widget'
  end
end
