# frozen_string_literal: true

require 'test_helper'
require 'json'

class WidgetTest < ActiveSupport::TestCase
  def parsed_config(html)
    json = html[%r{<script type="application/json" data-ideasbugs-config>(.*?)</script>}m, 1]
    JSON.parse(json.gsub('<\/', '</'))
  end

  test 'stays out of the host asset pipeline (no app/assets to auto-register)' do
    assert_empty Ideasbugs::Engine.paths['app/assets'].existent
    assert File.exist?(Ideasbugs::Widget::SOURCE)
  end

  test 'ships the endpoint, kinds, sections, and limits as JSON data' do
    Ideasbugs.config.sections = %w[Dashboard Billing]

    html = Ideasbugs::Widget.snippet(endpoint: '/feedback/feedbacks', locale: :en)
    config = parsed_config(html)

    assert_equal '/feedback/feedbacks', config['endpoint']
    assert_equal [
      { 'value' => 'bug', 'label' => 'Bug report' },
      { 'value' => 'feature', 'label' => 'Feature request' },
      { 'value' => 'other', 'label' => 'Other' }
    ], config['kinds']
    assert_equal %w[Dashboard Billing], config['sections']
    assert_equal({ 'enabled' => true, 'max' => 3, 'maxSize' => 5 * 1024 * 1024 }, config['screenshots'])
    assert_equal false, config['rtl']
  end

  test 'stamps the nonce on the widget script only' do
    html = Ideasbugs::Widget.snippet(endpoint: '/x', locale: :en, nonce: 'abc123')

    assert_includes html, '<script data-ideasbugs-widget nonce="abc123">'
    assert_includes html, '<script type="application/json" data-ideasbugs-config>'
    assert_not_includes html, 'data-ideasbugs-config nonce'
  end

  test 'escapes </ so config values cannot close the script block' do
    Ideasbugs.config.button_label = '</script><script>alert(1)</script>'

    html = Ideasbugs::Widget.snippet(endpoint: '/x', locale: :en)
    json = html[%r{<script type="application/json" data-ideasbugs-config>(.*?)</script>}m, 1]

    assert_not_includes json, '</script>'
    assert_equal '</script><script>alert(1)</script>', parsed_config(html)['buttonLabel']
  end

  test 'flags RTL locales' do
    html = Ideasbugs::Widget.snippet(endpoint: '/x', locale: :'ar-EG')

    assert_equal true, parsed_config(html)['rtl']
  end

  test 'localizes the labels' do
    I18n.with_locale(:fr) do
      html = Ideasbugs::Widget.snippet(endpoint: '/x', locale: :fr)

      assert_equal 'Signaler un bug / demander une fonctionnalité', parsed_config(html)['labels']['title']
    end
  end
end
