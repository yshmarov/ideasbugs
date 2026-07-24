# frozen_string_literal: true

require 'test_helper'

class WidgetSystemTest < ApplicationSystemTestCase
  test 'submits feedback end to end, with a screenshot' do
    visit '/sample'

    find('#fbe-button').click
    assert_selector '#fbe-dialog'

    # Client-side validation first: an empty message never leaves the browser.
    click_button 'Send feedback'
    assert_text 'Please enter a message.'
    assert_equal 0, FeedbackEngine::Feedback.count

    select 'Feature request', from: 'Type'
    fill_in 'Your message', with: 'Love it, but add dark mode'
    attach_file 'Screenshots', file_fixture('tiny.png')

    click_button 'Send feedback'
    assert_text 'Thanks for your feedback!'

    feedback = FeedbackEngine::Feedback.last

    assert_equal 'feature', feedback.kind
    assert_equal 'Love it, but add dark mode', feedback.message
    assert_includes feedback.page_url, '/sample'
    assert_equal 1, feedback.screenshots.count
  end

  test 'shows the section select when sections are configured' do
    FeedbackEngine.config.sections = %w[Billing Reports]
    visit '/sample'

    find('#fbe-button').click
    select 'Billing', from: 'Section'
    fill_in 'Your message', with: 'Billing is confusing'
    click_button 'Send feedback'

    assert_text 'Thanks for your feedback!'
    assert_equal 'Billing', FeedbackEngine::Feedback.last.section
  end

  test 'closes on Escape without submitting' do
    visit '/sample'

    find('#fbe-button').click
    fill_in 'Your message', with: 'Nearly sent'
    page.driver.browser.action.send_keys(:escape).perform

    assert_no_selector '#fbe-dialog'
    assert_equal 0, FeedbackEngine::Feedback.count
  end

  test 'opens from a host element carrying data-feedback-engine-open' do
    visit '/sample'

    find('#custom-opener').click

    assert_selector '#fbe-dialog'
  end

  test 'hides the floating button when show_button is off, custom trigger still works' do
    FeedbackEngine.config.show_button = false
    visit '/sample'

    assert_no_selector '#fbe-button'
    find('#custom-opener').click
    assert_selector '#fbe-dialog'
  end

  test 'keeps Tab focus inside the dialog' do
    visit '/sample'

    find('#fbe-button').click
    find('#fbe-dialog .fbe-primary').send_keys(:tab)

    assert page.evaluate_script('document.activeElement.closest("#fbe-dialog") !== null')
  end

  test 'rejects oversized files in the browser before uploading' do
    FeedbackEngine.config.max_screenshot_size = 10
    visit '/sample'

    find('#fbe-button').click
    fill_in 'Your message', with: 'Big file'
    attach_file 'Screenshots', file_fixture('tiny.png')
    click_button 'Send feedback'

    assert_text 'A screenshot is too large'
    assert_equal 0, FeedbackEngine::Feedback.count
  end
end
