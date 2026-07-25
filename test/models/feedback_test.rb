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

    test 'attaches screenshots' do
      feedback = Feedback.create!(kind: 'bug', message: 'See attached')
      feedback.screenshots.attach(
        io: File.open(file_fixture('tiny.png')),
        filename: 'tiny.png',
        content_type: 'image/png'
      )

      assert_predicate feedback, :screenshots?
    end
  end
end
