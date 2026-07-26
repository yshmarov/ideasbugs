# frozen_string_literal: true

require 'test_helper'

module Ideasbugs
  class MultitenancyTest < ActiveSupport::TestCase
    def feedback!(message:, tenant:)
      Feedback.create!(kind: 'bug', message: message, tenant: tenant)
    end

    test 'for_tenant isolates by key, and nil is the global board' do
      global = feedback!(message: 'global', tenant: nil)
      acme = feedback!(message: 'acme', tenant: 'acme')

      assert_equal [global], Feedback.for_tenant(nil).to_a
      assert_equal [acme], Feedback.for_tenant('acme').to_a
      assert_equal [global], Feedback.for_tenant('').to_a # blank normalizes to global
    end

    test 'Ideasbugs.tenant normalizes the resolver result to a string or nil' do
      Ideasbugs.config.tenant = ->(_request) { 'acme' }
      assert_equal 'acme', Ideasbugs.tenant(nil)

      Ideasbugs.config.tenant = ->(_request) { 123 }
      assert_equal '123', Ideasbugs.tenant(nil)

      Ideasbugs.config.tenant = ->(_request) { '' }
      assert_nil Ideasbugs.tenant(nil)

      Ideasbugs.config.tenant = ->(_request) {}
      assert_nil Ideasbugs.tenant(nil)
    end

    test 'Ideasbugs.for keys a host record by its GlobalID' do
      record = Object.new
      def record.to_gid = 'gid://dummy/Customer/5'

      mine = feedback!(message: 'mine', tenant: 'gid://dummy/Customer/5')
      feedback!(message: 'theirs', tenant: 'gid://dummy/Customer/6')

      assert_equal [mine], Ideasbugs.for(record).to_a
    end

    test 'has_feedback gives a host model a scoped relation' do
      klass = Class.new do
        extend Ideasbugs::HasFeedback

        has_feedback key: ->(record) { "cust-#{record.cid}" }

        attr_reader :cid

        def initialize(cid) = @cid = cid
      end

      customer = klass.new(7)
      mine = feedback!(message: 'ours', tenant: 'cust-7')
      feedback!(message: 'not ours', tenant: 'cust-8')

      assert_includes customer.feedback, mine
      assert_equal 1, customer.feedback.count
    end
  end
end
