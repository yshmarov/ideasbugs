# frozen_string_literal: true

require 'test_helper'

class DashboardTest < ActionDispatch::IntegrationTest
  def create_feedback(**attrs)
    Ideasbugs::Feedback.create!({ kind: 'bug', message: 'It broke' }.merge(attrs))
  end

  def create_feedback_with_screenshot(**attrs)
    create_feedback(**attrs).tap do |feedback|
      feedback.screenshots.attach(
        io: File.open(file_fixture('tiny.png')),
        filename: 'tiny.png',
        content_type: 'image/png'
      )
    end
  end

  def authorize_admin!
    Ideasbugs.config.authorize_admin = ->(_request) { true }
  end

  # --- not authorized (the default outside development) ---------------------

  test 'forbids the index by default' do
    get '/feedback'

    assert_response :forbidden
  end

  test 'forbids updates by default' do
    feedback = create_feedback

    patch "/feedback/feedbacks/#{feedback.id}", params: { feedback: { status: 'resolved' } }

    assert_response :forbidden
    assert_equal 'open', feedback.reload.status
  end

  test 'forbids screenshots by default' do
    feedback = create_feedback_with_screenshot

    get "/feedback/feedbacks/#{feedback.id}/screenshots/#{feedback.screenshots.first.id}"

    assert_response :forbidden
  end

  # --- authorized ------------------------------------------------------------

  test 'lists open feedback' do
    authorize_admin!
    create_feedback(message: 'Open bug')
    create_feedback(message: 'Solved one', status: 'resolved')

    get '/feedback'

    assert_response :ok
    assert_includes response.body, 'Open bug'
    assert_not_includes response.body, 'Solved one'
  end

  test 'searches message, author, and section, case-insensitively' do
    authorize_admin!
    create_feedback(message: 'Dark mode please')
    create_feedback(message: 'Broken button', author_label: 'darko@example.com')
    create_feedback(message: 'Slow page', section: 'Darkroom')
    create_feedback(message: 'Something different')

    get '/feedback', params: { q: 'DARK' }

    assert_includes response.body, 'Dark mode please'
    assert_includes response.body, 'Broken button'
    assert_includes response.body, 'Slow page'
    assert_not_includes response.body, 'Something different'
  end

  test 'treats LIKE wildcards in the query literally' do
    authorize_admin!
    create_feedback(message: 'Discount is 100% off')
    create_feedback(message: 'Plain message')

    get '/feedback', params: { q: '100%' }

    assert_includes response.body, 'Discount is 100'
    assert_not_includes response.body, 'Plain message'
  end

  test 'filters by status and kind' do
    authorize_admin!
    create_feedback(message: 'A bug in review', status: 'in_review')
    create_feedback(message: 'A feature idea', kind: 'feature', status: 'in_review')

    get '/feedback', params: { status: 'in_review', kind: 'feature' }

    assert_includes response.body, 'A feature idea'
    assert_not_includes response.body, 'A bug in review'
  end

  test 'shows one feedback with its details' do
    authorize_admin!
    feedback = create_feedback(section: 'Billing', page_url: 'http://example.com/x',
                               author_label: 'user@example.com')

    get "/feedback/feedbacks/#{feedback.id}"

    assert_includes response.body, 'It broke'
    assert_includes response.body, 'Billing'
    assert_includes response.body, 'user@example.com'
  end

  test 'renders screenshots via the gated engine route, not blob URLs' do
    authorize_admin!
    feedback = create_feedback_with_screenshot
    screenshot_path = "/feedback/feedbacks/#{feedback.id}/screenshots/#{feedback.screenshots.first.id}"

    get "/feedback/feedbacks/#{feedback.id}"

    assert_response :ok
    assert_includes response.body, %(src="#{screenshot_path}")
    assert_not_includes response.body, '/rails/active_storage/'
  end

  test 'streams a screenshot to an admin' do
    authorize_admin!
    feedback = create_feedback_with_screenshot

    get "/feedback/feedbacks/#{feedback.id}/screenshots/#{feedback.screenshots.first.id}"

    assert_response :ok
    assert_equal 'image/png', response.media_type
    assert_includes response.headers['Content-Disposition'], 'inline'
    assert_equal feedback.screenshots.first.byte_size, response.body.bytesize
  end

  test '404s for a screenshot of another feedback' do
    authorize_admin!
    feedback = create_feedback_with_screenshot
    other = create_feedback

    get "/feedback/feedbacks/#{other.id}/screenshots/#{feedback.screenshots.first.id}"

    assert_response :not_found
  end

  test 'updates the status' do
    authorize_admin!
    feedback = create_feedback

    patch "/feedback/feedbacks/#{feedback.id}", params: { feedback: { status: 'resolved' } }

    assert_response :see_other
    assert_equal 'resolved', feedback.reload.status
  end

  test 'deletes feedback' do
    authorize_admin!
    feedback = create_feedback

    delete "/feedback/feedbacks/#{feedback.id}"

    assert_response :see_other
    assert_not Ideasbugs::Feedback.exists?(feedback.id)
  end
end
