# frozen_string_literal: true

require 'test_helper'

module Ideasbugs
  class FeedbackTest < ActiveSupport::TestCase
    test 'is valid with a message and a known kind' do
      assert_predicate Feedback.new(kind: 'bug', message: 'It broke'), :valid?
    end

    test 'requires a message' do
      feedback = Feedback.new(kind: 'bug', message: '')

      assert_not feedback.valid?
      assert feedback.errors[:message].present?
    end

    test 'rejects kinds outside the configured list' do
      assert_not Feedback.new(kind: 'praise', message: 'Nice!').valid?
    end

    test 'accepts kinds the host adds to the config' do
      Ideasbugs.config.kinds = %w[bug praise]

      assert_predicate Feedback.new(kind: 'praise', message: 'Nice!'), :valid?
    end

    test 'defaults to open and validates status' do
      feedback = Feedback.create!(kind: 'bug', message: 'It broke')

      assert_predicate feedback, :open?

      feedback.status = 'in_review'

      assert_predicate feedback, :valid?
      assert_predicate feedback, :in_review?

      feedback.status = 'wontfix'

      assert_not feedback.valid?
    end

    test 'exposes one relation scope per documented status' do
      records = Feedback::STATUSES.to_h do |status|
        [status, Feedback.create!(kind: 'other', message: status, status:)]
      end

      Feedback::STATUSES.each do |status|
        assert_equal [records.fetch(status)], Feedback.public_send(status).to_a
      end

      tenant_open = Feedback.create!(kind: 'bug', message: 'Tenant open', tenant: 'acme')
      Feedback.create!(kind: 'bug', message: 'Other tenant open', tenant: 'other')

      assert_equal [tenant_open], Feedback.for_tenant('acme').open.newest_first.to_a
    end

    test 'attaches screenshots' do
      feedback = Feedback.create!(kind: 'bug', message: 'See attached')
      feedback.screenshots.attach(
        io: File.open(file_fixture('tiny.png')),
        filename: 'tiny.png',
        content_type: 'image/png'
      )

      assert_predicate feedback, :screenshots?
    end

    Author = Struct.new(:id, :email)

    test 'submit files feedback the way the widget does' do
      submitted = []
      Ideasbugs.config.on_submit = ->(feedback) { submitted << feedback }

      feedback = Feedback.submit(
        { 'kind' => 'bug', 'message' => 'It broke', 'status' => 'resolved',
          'page_url' => 'https://example.com/a?token=secret' },
        author: Author.new(7, 'ann@example.com'), tenant: 'org-1', user_agent: 'Script/1.0'
      )

      assert_predicate feedback, :persisted?
      assert_equal 'https://example.com/a', feedback.page_url
      assert_equal ['7', Author.name, 'ann@example.com', 'org-1', 'Script/1.0', 'open'],
                   feedback.attributes.values_at('author_id', 'author_type', 'author_label', 'tenant', 'user_agent',
                                                 'status')
      assert_equal [feedback], submitted
    end

    test 'shows the author reference when the host stores no label' do
      feedback = Feedback.new(author_id: '7', author_type: 'User')

      assert_equal 'User #7', feedback.author_reference
      feedback.author_label = 'ann@example.com'

      assert_equal 'ann@example.com', feedback.author_reference
      assert_nil Feedback.new.author_reference
    end

    test 'submit returns errors without saving or notifying' do
      Ideasbugs.config.on_submit = ->(_feedback) { flunk 'notified' }

      feedback = Feedback.submit({ kind: 'bug', message: '' })

      assert_not feedback.persisted?
      assert feedback.errors[:message].present?
    end
  end

  # Same schema-change caveats as DuplicatesLegacySchemaTest.
  class AuthorTypeLegacySchemaTest < ActiveSupport::TestCase
    self.use_transactional_tests = false

    setup do
      @connection = Feedback.connection
      @connection.remove_column :ideasbugs_feedbacks, :author_type
      forget_schema
    end

    teardown do
      Feedback.delete_all
      @connection.add_column :ideasbugs_feedbacks, :author_type, :string
      forget_schema
    end

    def forget_schema
      Feedback.connection_pool.connections.each(&:clear_cache!)
      Feedback.reset_column_information
    end

    test 'installs without the column still attribute the author' do
      author = FeedbackTest::Author.new(7, 'ann@example.com')
      feedback = Feedback.submit({ kind: 'bug', message: 'It broke' }, author:)

      assert_not Feedback.tracks_author_type?
      assert_equal %w[7 ann@example.com], [feedback.reload.author_id, feedback.author_label]
      assert_equal '#7', Feedback.new(author_id: '7').author_reference
    end
  end
end
