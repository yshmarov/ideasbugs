# frozen_string_literal: true

require 'test_helper'

module Ideasbugs
  # Multi-tenancy: with config.tenant set, every submission is stamped and the
  # dashboard scopes to the resolved tenant. Here the resolver reads a request
  # param so a single test can act as different tenants; a real app would
  # resolve from the session, subdomain, or Current.
  class TenantTest < ActionDispatch::IntegrationTest
    setup do
      Ideasbugs.config.tenant = ->(request) { request.params[:tenant].presence }
    end

    def authorize_admin!
      Ideasbugs.config.authorize_admin = ->(_request) { true }
    end

    def feedback!(message:, tenant:, status: 'open')
      Feedback.create!(kind: 'bug', message: message, status: status, tenant: tenant)
    end

    # --- writes stamp the tenant --------------------------------------------

    test 'a submission is stamped with the resolved tenant' do
      post '/feedback/feedbacks', params: { tenant: 'acme', feedback: { kind: 'bug', message: 'broken' } }
      assert_response :created
      assert_equal 'acme', Feedback.last.tenant
    end

    test 'with no tenant resolved a submission stays on the global board' do
      post '/feedback/feedbacks', params: { feedback: { kind: 'bug', message: 'broken' } }
      assert_response :created
      assert_nil Feedback.last.tenant
    end

    # --- dashboard is scoped -------------------------------------------------

    test 'the dashboard shows only the current tenant, with scoped counts' do
      feedback!(message: 'Acme bug', tenant: 'acme')
      feedback!(message: 'Globex bug', tenant: 'globex')
      authorize_admin!

      get '/feedback', params: { tenant: 'acme' }
      assert_response :ok
      assert_includes response.body, 'Acme bug'
      assert_not_includes response.body, 'Globex bug'
    end

    test 'an admin cannot open, triage, or delete another tenant record' do
      other = feedback!(message: 'Globex only', tenant: 'globex')
      authorize_admin!

      get "/feedback/feedbacks/#{other.id}", params: { tenant: 'acme' }
      assert_response :not_found

      patch "/feedback/feedbacks/#{other.id}", params: { tenant: 'acme', feedback: { status: 'resolved' } }
      assert_response :not_found
      assert_equal 'open', other.reload.status

      delete "/feedback/feedbacks/#{other.id}", params: { tenant: 'acme' }
      assert_response :not_found
      assert Feedback.exists?(other.id)
    end

    # --- screenshot isolation ------------------------------------------------

    test 'screenshots of another tenant are not reachable' do
      feedback = feedback!(message: 'with shot', tenant: 'acme')
      feedback.screenshots.attach(io: File.open(file_fixture('tiny.png')),
                                  filename: 'tiny.png', content_type: 'image/png')
      shot_id = feedback.screenshots.first.id
      authorize_admin!

      get "/feedback/feedbacks/#{feedback.id}/screenshots/#{shot_id}", params: { tenant: 'globex' }
      assert_response :not_found

      get "/feedback/feedbacks/#{feedback.id}/screenshots/#{shot_id}", params: { tenant: 'acme' }
      assert_response :ok
      assert_equal 'image/png', response.media_type
    end
  end
end
