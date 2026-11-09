# frozen_string_literal: true

require 'test_helper'

module Ideasbugs
  class DuplicatesDashboardTest < ActionDispatch::IntegrationTest
    setup do
      Ideasbugs.config.authorize_admin = ->(_request) { true }
      Ideasbugs.config.tenant = ->(request) { request.params[:tenant].presence }
    end

    def feedback!(message, **attrs)
      Feedback.create!({ kind: 'feature', message: message }.merge(attrs))
    end

    test 'marking a duplicate takes it out of the queue and lists it on the original' do
      original = feedback!('Export to CSV')
      duplicate = feedback!('I need a CSV download')

      post "/feedback/feedbacks/#{duplicate.id}/duplicate", params: { original_id: "##{original.id}" }

      assert_redirected_to "/feedback/feedbacks?feedback_id=#{original.id}&status=open"
      assert_equal original, duplicate.reload.duplicate_of

      follow_redirect!

      assert_select '.record-list', text: /I need a CSV download/, count: 0
      assert_select '.tabs a.active .count', text: '1'
      assert_select '.record-list', text: /Duplicates: 1/
      assert_select '.duplicates a[href*=?]', "feedback_id=#{duplicate.id}", text: /I need a CSV download/
    end

    test 'a duplicate shows its original instead of a status switch, and can be taken back' do
      original = feedback!('Export to CSV', status: 'in_review')
      duplicate = feedback!('I need a CSV download')
      duplicate.mark_duplicate_of!(original)

      get "/feedback/feedbacks/#{duplicate.id}"

      assert_select '.status-switch', count: 0
      assert_select '.duplicate-of a[href*=?]', "feedback_id=#{original.id}"
      assert_select '.mark-duplicate', count: 0

      delete "/feedback/feedbacks/#{duplicate.id}/duplicate"

      assert_not duplicate.reload.duplicate?
      assert_redirected_to "/feedback/feedbacks?feedback_id=#{duplicate.id}&status=open"
    end

    test 'an unknown or cross-tenant original is refused with a message' do
      duplicate = feedback!('Acme ask', tenant: 'acme')
      elsewhere = feedback!('Globex ask', tenant: 'globex')

      post "/feedback/feedbacks/#{duplicate.id}/duplicate", params: { tenant: 'acme', original_id: elsewhere.id }
      follow_redirect!(params: { tenant: 'acme' })

      assert_not duplicate.reload.duplicate?
      assert_select '.flash.alert', text: I18n.t('ideasbugs.dashboard.duplicate_not_found')
    end

    test 'an invalid original explains why' do
      feedback = feedback!('Export to CSV')

      post "/feedback/feedbacks/#{feedback.id}/duplicate", params: { original_id: feedback.id }
      follow_redirect!

      assert_select '.flash.alert', text: /must be another feedback/
    end
  end

  # The schema change runs outside a test transaction, and every pooled
  # connection drops its prepared statements after it: SQLite statements keep
  # the column list they were prepared with, so a later test would load rows
  # without the column.
  class DuplicatesLegacySchemaTest < ActionDispatch::IntegrationTest
    self.use_transactional_tests = false

    setup do
      Ideasbugs.config.authorize_admin = ->(_request) { true }
      @connection = Feedback.connection
      @connection.remove_index :ideasbugs_feedbacks, :duplicate_of_id
      @connection.remove_column :ideasbugs_feedbacks, :duplicate_of_id
      forget_schema
    end

    teardown do
      Feedback.delete_all
      @connection.add_reference :ideasbugs_feedbacks, :duplicate_of, index: true
      forget_schema
    end

    def forget_schema
      Feedback.connection_pool.connections.each(&:clear_cache!)
      Feedback.reset_column_information
    end

    test 'installs without the column keep a working dashboard and no duplicate controls' do
      feedback = Feedback.create!(kind: 'feature', message: 'Export to CSV')

      assert_not Feedback.tracks_duplicates?

      get '/feedback', params: { feedback_id: feedback.id }

      assert_response :ok
      assert_select '.record-list', text: /Export to CSV/
      assert_select '.mark-duplicate', count: 0

      post "/feedback/feedbacks/#{feedback.id}/duplicate", params: { original_id: feedback.id }

      assert_response :not_found

      delete "/feedback/feedbacks/#{feedback.id}"

      assert_not Feedback.exists?(feedback.id)
    end
  end
end
