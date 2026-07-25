# frozen_string_literal: true

require 'test_helper'

class WidgetSystemTest < ApplicationSystemTestCase
  test 'submits feedback end to end, with a screenshot' do
    visit '/sample'

    find('#idb-button').click
    assert_selector '#idb-dialog'

    # Client-side validation first: an empty message never leaves the browser.
    click_button 'Send feedback'
    assert_text 'Please enter a message.'
    assert_equal 0, Ideasbugs::Feedback.count

    select 'Feature request', from: 'Type'
    fill_in 'Your message', with: 'Love it, but add dark mode'
    attach_file 'Screenshots', file_fixture('tiny.png')

    click_button 'Send feedback'
    assert_text 'Thanks for your feedback!'

    feedback = Ideasbugs::Feedback.last

    assert_equal 'feature', feedback.kind
    assert_equal 'Love it, but add dark mode', feedback.message
    assert_includes feedback.page_url, '/sample'
    assert_equal 1, feedback.screenshots.count
  end

  test 'shows the section select when sections are configured' do
    Ideasbugs.config.sections = %w[Billing Reports]
    visit '/sample'

    find('#idb-button').click
    select 'Billing', from: 'Section'
    fill_in 'Your message', with: 'Billing is confusing'
    click_button 'Send feedback'

    assert_text 'Thanks for your feedback!'
    assert_equal 'Billing', Ideasbugs::Feedback.last.section
  end

  test 'closes on Escape without submitting' do
    visit '/sample'

    find('#idb-button').click
    fill_in 'Your message', with: 'Nearly sent'
    page.driver.browser.action.send_keys(:escape).perform

    assert_no_selector '#idb-dialog'
    assert_equal 0, Ideasbugs::Feedback.count
  end

  test 'opens from a host element carrying data-ideasbugs-open' do
    visit '/sample'

    find('#custom-opener').click

    assert_selector '#idb-dialog'
  end

  test 'hides the floating button when show_button is off, custom trigger still works' do
    Ideasbugs.config.show_button = false
    visit '/sample'

    assert_no_selector '#idb-button'
    find('#custom-opener').click
    assert_selector '#idb-dialog'
  end

  test 'keeps Tab focus inside the dialog' do
    visit '/sample'

    find('#idb-button').click
    find('#idb-dialog .idb-primary').send_keys(:tab)

    assert page.evaluate_script('document.activeElement.closest("#idb-dialog") !== null')
  end

  test 'rejects oversized files in the browser before uploading' do
    Ideasbugs.config.max_screenshot_size = 10
    visit '/sample'

    find('#idb-button').click
    fill_in 'Your message', with: 'Big file'
    attach_file 'Screenshots', file_fixture('tiny.png')
    click_button 'Send feedback'

    assert_text 'A screenshot is too large'
    assert_equal 0, Ideasbugs::Feedback.count
  end
end
