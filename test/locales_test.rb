# frozen_string_literal: true

require 'test_helper'
require 'yaml'

class LocalesTest < ActiveSupport::TestCase
  LOCALE_FILES = Dir[File.expand_path('../config/locales/*.yml', __dir__)]

  # The widget keys every locale must ship, plus the branded admin dashboard
  # title so translated installations do not fall back to a generic label.
  WIDGET_KEYS = %w[
    button title kind kinds.bug kinds.feature kinds.other section section_any
    message message_placeholder screenshots screenshots_hint submit cancel
    close thanks error_blank error_save error_too_many error_too_large
    error_rate_limited dashboard.title
  ].freeze

  PLACEHOLDERS = {
    'screenshots_hint' => ['%{count}', '%{size}'],
    'error_too_many' => ['%{count}'],
    'error_too_large' => ['%{size}']
  }.freeze

  test 'ships at least the six original languages' do
    locales = LOCALE_FILES.map { |f| File.basename(f)[/ideasbugs\.(.+)\.yml/, 1] }

    assert_operator locales.to_set, :>=, %w[en es fr de pt uk].to_set
  end

  LOCALE_FILES.each do |file|
    locale = File.basename(file)[/ideasbugs\.(.+)\.yml/, 1]

    test "#{locale} has a single root key and every widget key" do
      yaml = YAML.safe_load_file(file)

      assert_equal [locale], yaml.keys
      data = yaml.fetch(locale).fetch('ideasbugs')
      missing = WIDGET_KEYS - flatten_keys(data)

      assert_empty missing, "#{locale} is missing #{missing.join(', ')}"
    end

    test "#{locale} keeps the interpolation placeholders intact" do
      data = YAML.safe_load_file(file).fetch(locale).fetch('ideasbugs')
      PLACEHOLDERS.each do |key, tokens|
        tokens.each do |token|
          assert_includes data.fetch(key), token, "#{locale}.#{key} is missing #{token}"
        end
      end
    end

    test "#{locale} has no blank values" do
      data = YAML.safe_load_file(file).fetch(locale).fetch('ideasbugs')
      values = data.values.flat_map { |v| v.is_a?(Hash) ? v.values : [v] }
      values.each do |value|
        assert_kind_of String, value
        assert value.strip.present?, "#{locale} has a blank value"
      end
    end
  end

  private

  def flatten_keys(hash, prefix = nil)
    hash.flat_map do |key, value|
      full = [prefix, key].compact.join('.')
      value.is_a?(Hash) ? flatten_keys(value, full) : [full]
    end
  end
end
