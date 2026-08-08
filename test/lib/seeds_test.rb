# frozen_string_literal: true

require 'test_helper'

class SeedsTest < ActiveSupport::TestCase
  test 'loads idempotent demo feedback across statuses' do
    first = Ideasbugs::Seeds.load!
    second = Ideasbugs::Seeds.load!

    assert_equal 3, first.size
    assert_equal first.map(&:id), second.map(&:id)
    assert_equal 3, Ideasbugs::Feedback.where("author_id LIKE 'ideasbugs-demo:%'").count
    assert_equal Ideasbugs::Feedback::STATUSES.sort, first.map(&:status).sort
    assert_equal %w[bug feature other], first.map(&:kind)
    assert_includes first.find(&:open?).message, 'Move it to In review'
    assert_includes first.find(&:resolved?).message, 'set authorize_admin before production'
  end

  test 'can scope demo feedback to a tenant' do
    feedback = Ideasbugs::Seeds.load!(tenant: 'gid://dummy/Account/7')

    assert_equal ['gid://dummy/Account/7'], feedback.map(&:tenant).uniq
  end
end
