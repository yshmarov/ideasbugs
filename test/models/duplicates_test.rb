# frozen_string_literal: true

require 'test_helper'

module Ideasbugs
  class DuplicatesTest < ActiveSupport::TestCase
    def feedback!(**attrs)
      Feedback.create!({ kind: 'feature', message: 'Export to CSV' }.merge(attrs))
    end

    test 'a duplicate points at its original and leaves the queue' do
      original = feedback!
      duplicate = feedback!(message: 'I need a CSV download')

      duplicate.mark_duplicate_of!(original)

      assert_predicate duplicate, :duplicate?
      assert_equal [duplicate], original.duplicates.to_a
      assert_equal [original], Feedback.originals.to_a
    end

    test 'a duplicate of a duplicate points at the original' do
      original = feedback!
      first = feedback!
      second = feedback!
      first.mark_duplicate_of!(original)

      second.mark_duplicate_of!(first)

      assert_equal original, second.reload.duplicate_of
    end

    test 'marking an original moves its duplicates along, one level deep' do
      original = feedback!
      newer = feedback!
      duplicate = feedback!
      duplicate.mark_duplicate_of!(newer)

      newer.mark_duplicate_of!(original)

      assert_equal original, duplicate.reload.duplicate_of
      assert_equal [duplicate, newer].sort_by(&:id), original.duplicates.order(:id).to_a
    end

    test 'marking an original as a duplicate of its own duplicate swaps the two' do
      original = feedback!
      better = feedback!
      other = feedback!
      better.mark_duplicate_of!(original)
      other.mark_duplicate_of!(original)

      original.mark_duplicate_of!(better)

      assert_not better.reload.duplicate?
      assert_equal better, original.reload.duplicate_of
      assert_equal better, other.reload.duplicate_of
    end

    test 'refuses itself and other boards, and changes nothing' do
      feedback = feedback!(tenant: 'acme')
      duplicate = feedback!(tenant: 'acme')
      duplicate.mark_duplicate_of!(feedback)
      elsewhere = feedback!(tenant: 'globex')

      assert_raises(ActiveRecord::RecordInvalid) { feedback.mark_duplicate_of!(feedback) }
      assert_raises(ActiveRecord::RecordInvalid) { feedback.mark_duplicate_of!(elsewhere) }
      assert_equal feedback, duplicate.reload.duplicate_of
      assert_not feedback.reload.duplicate?
    end

    test 'unmarking puts a duplicate back in the queue with its own status' do
      original = feedback!(status: 'resolved')
      duplicate = feedback!
      duplicate.mark_duplicate_of!(original)

      duplicate.unmark_duplicate!

      assert_not duplicate.reload.duplicate?
      assert_predicate duplicate, :open?
    end

    test 'deleting an original releases its duplicates' do
      original = feedback!
      duplicate = feedback!
      duplicate.mark_duplicate_of!(original)

      original.destroy!

      assert_not duplicate.reload.duplicate?
    end
  end
end
