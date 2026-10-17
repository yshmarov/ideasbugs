# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

require_relative 'dummy/config/environment'
require 'rails/test_help'
require 'rack/test'

require_relative 'support/schema'

module ActiveSupport
  class TestCase
    self.file_fixture_path = File.expand_path('fixtures/files', __dir__)

    # Start every test from a fresh config, so a stub in one test can never
    # leak into another under random order. The cache reset keeps the rate
    # limiter's per-IP counters from tripping later tests.
    setup do
      Ideasbugs.instance_variable_set(:@config, Ideasbugs::Configuration.new)
      Rails.cache.clear
    end

    teardown do
      Ideasbugs.instance_variable_set(:@config, nil)
    end
  end
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1200, 900]
end
