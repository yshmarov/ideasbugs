# frozen_string_literal: true

require 'test_helper'

class FeedbacksTest < ActionDispatch::IntegrationTest
  def png
    Rack::Test::UploadedFile.new(file_fixture('tiny.png'), 'image/png')
  end

  def txt
    Rack::Test::UploadedFile.new(file_fixture('note.txt'), 'text/plain')
  end

  test 'stores the feedback with request metadata' do
    post '/feedback/feedbacks',
         params: { feedback: { kind: 'bug', section: 'Billing', message: 'It broke',
                               page_url: 'http://example.com/billing' } },
         headers: { 'User-Agent' => 'TestBrowser/1.0' }

    assert_response :created

    feedback = Ideasbugs::Feedback.last

    assert_equal 'bug', feedback.kind
    assert_equal 'Billing', feedback.section
    assert_equal 'It broke', feedback.message
    assert_equal 'http://example.com/billing', feedback.page_url
    assert_equal 'TestBrowser/1.0', feedback.user_agent
    assert_equal 'open', feedback.status
  end

  test 'attributes the author via the configured hooks' do
    user = Struct.new(:id, :email).new(42, 'user@example.com')
    Ideasbugs.config.current_user = ->(_request) { user }

    post '/feedback/feedbacks', params: { feedback: { kind: 'other', message: 'Hello' } }

    feedback = Ideasbugs::Feedback.last

    assert_equal '42', feedback.author_id
    assert_equal 'user@example.com', feedback.author_label
  end

  test 'calls the on_submit hook' do
    submitted = []
    Ideasbugs.config.on_submit = ->(feedback) { submitted << feedback }

    post '/feedback/feedbacks', params: { feedback: { kind: 'other', message: 'Hello' } }

    assert_equal ['Hello'], submitted.map(&:message)
  end

  test 'still accepts the submission when the on_submit hook raises' do
    Ideasbugs.config.on_submit = ->(_feedback) { raise 'host mailer exploded' }

    post '/feedback/feedbacks', params: { feedback: { kind: 'other', message: 'Hello' } }

    assert_response :created
    assert_equal 1, Ideasbugs::Feedback.count
  end

  test 'rejects a blank message' do
    post '/feedback/feedbacks', params: { feedback: { kind: 'bug', message: '' } }

    assert_response :unprocessable_entity
    assert response.parsed_body['errors'].present?
    assert_equal 0, Ideasbugs::Feedback.count
  end

  test 'rejects an unknown kind' do
    post '/feedback/feedbacks', params: { feedback: { kind: 'spam', message: 'Hi' } }

    assert_response :unprocessable_entity
  end

  test 'throttles a flood of submissions per IP' do
    skip 'rate_limit requires Rails 7.2+' unless Ideasbugs::FeedbacksController.respond_to?(:rate_limit)

    10.times do |i|
      post '/feedback/feedbacks', params: { feedback: { kind: 'bug', message: "Flood #{i}" } }

      assert_response :created
    end

    post '/feedback/feedbacks', params: { feedback: { kind: 'bug', message: 'One too many' } }

    assert_response :too_many_requests
    assert_includes response.parsed_body['errors'].first, 'Too many submissions'
    assert_equal 10, Ideasbugs::Feedback.count
  end

  test 'is forbidden when the gate says no' do
    Ideasbugs.config.enabled = ->(_request) { false }

    post '/feedback/feedbacks', params: { feedback: { kind: 'bug', message: 'It broke' } }

    assert_response :forbidden
    assert_equal 0, Ideasbugs::Feedback.count
  end

  test 'attaches uploaded images' do
    post '/feedback/feedbacks',
         params: { feedback: { kind: 'bug', message: 'See attached', screenshots: [png] } }

    assert_response :created
    assert_equal 1, Ideasbugs::Feedback.last.screenshots.count
  end

  test 'rejects more screenshots than allowed' do
    Ideasbugs.config.max_screenshots = 1

    post '/feedback/feedbacks',
         params: { feedback: { kind: 'bug', message: 'Two shots', screenshots: [png, png] } }

    assert_response :unprocessable_entity
    assert_equal 0, Ideasbugs::Feedback.count
  end

  test 'rejects oversized screenshots' do
    Ideasbugs.config.max_screenshot_size = 10

    post '/feedback/feedbacks',
         params: { feedback: { kind: 'bug', message: 'Big shot', screenshots: [png] } }

    assert_response :unprocessable_entity
  end

  test 'rejects non-image uploads' do
    post '/feedback/feedbacks',
         params: { feedback: { kind: 'bug', message: 'A file', screenshots: [txt] } }

    assert_response :unprocessable_entity
  end

  test 'rejects uploads when screenshots are disabled' do
    Ideasbugs.config.screenshots = false

    post '/feedback/feedbacks',
         params: { feedback: { kind: 'bug', message: 'Shot', screenshots: [png] } }

    assert_response :unprocessable_entity
  end

  test 'still accepts feedback without screenshots when disabled' do
    Ideasbugs.config.screenshots = false

    post '/feedback/feedbacks', params: { feedback: { kind: 'bug', message: 'No shot' } }

    assert_response :created
  end
end
