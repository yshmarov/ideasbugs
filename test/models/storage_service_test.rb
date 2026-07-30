# frozen_string_literal: true

require 'test_helper'

module Ideasbugs
  class StorageServiceTest < ActiveSupport::TestCase
    MODEL_PATH = Engine.root.join('app/models/ideasbugs/feedback.rb').to_s

    test 'screenshots use the app default service by default' do
      assert_nil Feedback.attachment_reflections['screenshots'].options[:service_name]
    end

    test 'storage_service routes screenshots to the named service' do
      Ideasbugs.config.storage_service = :ideasbugs_uploads
      reload_model!

      assert_equal :ideasbugs_uploads,
                   Feedback.attachment_reflections['screenshots'].options[:service_name]

      feedback = Feedback.create!(kind: 'bug', message: 'See attached')
      feedback.screenshots.attach(
        io: File.open(file_fixture('tiny.png')),
        filename: 'tiny.png',
        content_type: 'image/png'
      )

      assert_equal 'ideasbugs_uploads', feedback.screenshots.first.blob.service_name
    ensure
      Ideasbugs.config.storage_service = nil
      reload_model!
    end

    private

    def reload_model!
      Ideasbugs.send(:remove_const, :Feedback)
      load MODEL_PATH
    end
  end
end
