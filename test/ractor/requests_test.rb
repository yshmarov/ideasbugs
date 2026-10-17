# frozen_string_literal: true

# A separate process: ractorize! freezes Rails and cannot share a process with
# the ordinary suite, whose tests deliberately replace configuration per test.
require 'tmpdir'
require 'fileutils'
require 'json'
require 'rack/mock'

ENV['RAILS_ENV'] = 'ractor'
ractor_directory = Dir.mktmpdir('ideasbugs-ractor-')
ENV['DATABASE_URL'] = "sqlite3:#{ractor_directory}/test.sqlite3"
at_exit { FileUtils.remove_entry(ractor_directory) }

require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'active_storage/engine' if ENV['RACTOR_MEDIA'] == '1'
require 'ideasbugs'
require 'global_id'
GlobalID.app = +'ractor-host'
require 'minitest/autorun'
require 'active_support/ractors'

raise 'Use Rails edge and Ruby 4.0+ for test:ractor' unless Rails::Application.method_defined?(:ractorize!) &&
                                                            defined?(Ractor.shareable_lambda)

ActiveSupport::Ractors.unshareable_proc_action = :raise
FileUtils.mkdir_p("#{ractor_directory}/config/environments")
File.write("#{ractor_directory}/config/environments/ractor.rb", "# Dedicated Ractor host\n")

class RactorHost < Rails::Application
  config.load_defaults 7.1
  config.secret_key_base = 'ractor-test-secret-not-used-outside-tests'
  config.eager_load = true
  config.enable_reloading = false
  config.hosts = []
  config.logger = ActiveSupport::Ractors::Logger.new(ENV['RACTOR_DEBUG'] ? $stderr : nil)
  config.cache_store = :null_store
  config.public_file_server.enabled = false
  config.action_dispatch.show_exceptions = :none
  config.action_controller.allow_forgery_protection = false
  config.active_record.maintain_test_schema = false
  config.i18n.available_locales = %i[en fr]
end
if defined?(ActiveStorage)
  RactorHost.config.active_storage.service = :ractor_test
  RactorHost.config.active_storage.service_configurations = {
    'ractor_test' => { 'service' => 'Disk', 'root' => "#{ractor_directory}/storage" }
  }
  RactorHost.config.active_job.queue_adapter = :inline
end
RactorHost.config.root = ractor_directory
File.write("#{ractor_directory}/config/routes.rb",
           "Rails.application.routes.draw { mount_ideasbugs at: '/feedback' }\n")
Ideasbugs.config.enabled_environments = %w[ractor] if Ideasbugs.config.respond_to?(:enabled_environments)
# A shareable test counter. Mutable storage lives on the main Ractor, so the
# test proves that successive worker Ractors share a rate-limit bucket.
class RactorCounter
  @counts = {}

  def self.increment(key, _amount = 1, **_options)
    if Ractor.main?
      @counts[key] = @counts.fetch(key, 0) + 1
    else
      shared_key = Ractor.make_shareable(key, copy: true)
      ActiveSupport::Ractors.on_main(self) { increment(shared_key) }
    end
  end
end

Ideasbugs.config.rate_limit = Ideasbugs.config.rate_limit.merge(store: RactorCounter, to: 2, by: lambda {
  request.remote_ip
})
RactorHost.initialize!
require_relative '../support/schema'

RactorUser = Data.define(:id, :email)
Ideasbugs.configure do |config|
  config.enabled = ->(request) { request.get_header('HTTP_X_DISABLED') != 'yes' }
  config.authorize_admin = ->(request) { request.get_header('HTTP_X_ADMIN') == 'yes' }
  config.current_user = lambda { |request|
    RactorUser.new(id: request.get_header('HTTP_X_USER'), email: 'ractor@example.com')
  }
  config.tenant = ->(request) { request.get_header('HTTP_X_TENANT') }
  config.on_submit = ->(feedback) { feedback.update_column(:author_label, "#{feedback.author_label}:notified") }
end
class RactorCustomerBase < ActiveRecord::Base
  self.abstract_class = true
  has_feedback(as: :parent_feedback, key: ->(record) { record.tenant.to_s })
end

class RactorCustomer < RactorCustomerBase
  self.table_name = 'ideasbugs_feedbacks'
  include GlobalID::Identification

  has_feedback(key: ->(record) { record.tenant.to_s })
  has_feedback(as: :global_feedback)
end
Rails.application.ractorize!

class RactorRequestsTest < Minitest::Test
  def start_request(method, path, params: {}, headers: {})
    input = params.is_a?(String) ? params : Rack::Utils.build_nested_query(params)
    content_type = headers.fetch('CONTENT_TYPE', 'application/x-www-form-urlencoded')
    options = headers.merge(method: method, 'CONTENT_TYPE' => content_type,
                            'CONTENT_LENGTH' => input.bytesize.to_s)
    env = Rack::MockRequest.env_for(path, options)
    env.delete('rack.input')
    env.delete('rack.errors')
    Ractor.new(env, input) do |environment, data|
      environment['rack.input'] = StringIO.new(data)
      environment['rack.errors'] = StringIO.new
      status, response_headers, response_body = Rails.application.call(environment)
      body = +''
      response_body.each { |part| body << part }
      response_body.close if response_body.respond_to?(:close)
      [status, response_headers, body]
    end
  end

  def request(...) = start_request(...).value

  def test_rate_limit_counts_across_worker_ractors
    headers = { 'REMOTE_ADDR' => '198.51.100.42', 'HTTP_X_USER' => 'rate-user' }
    params = { feedback: { kind: 'bug', message: 'rate test' } }
    statuses = 3.times.map do
      request('POST', '/feedback/feedbacks', params: params, headers: headers).first
    end
    assert_equal [201, 201, 429], statuses
  end

  def upload(path, fields:, field:, filename:, bytes:, content_type:, headers: {})
    boundary = 'ractor-upload-boundary'
    input = fields.map do |key, value|
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{key}\"\r\n\r\n#{value}\r\n"
    end.join
    input << "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{field}\"; filename=\"#{filename}\"\r\n"
    input << "Content-Type: #{content_type}\r\n\r\n#{bytes}\r\n--#{boundary}--\r\n"
    headers = headers.merge('CONTENT_TYPE' => "multipart/form-data; boundary=#{boundary}",
                            'REMOTE_ADDR' => '198.51.100.43', 'HTTP_X_USER' => 'upload')
    request('POST', path, params: input, headers: headers)
  end

  def test_upload_runs_in_a_worker_ractor
    skip 'Run with RACTOR_MEDIA=1 for Active Storage integration' unless defined?(ActiveStorage)

    bytes = File.binread(File.expand_path('../fixtures/files/tiny.png', __dir__))
    status, _, body = upload('/feedback/feedbacks',
                             fields: { 'feedback[kind]' => 'bug', 'feedback[message]' => 'upload' },
                             field: 'feedback[screenshots][]', filename: 'tiny.png',
                             bytes: bytes, content_type: 'image/png',
                             headers: { 'HTTP_X_TENANT' => 'upload' })
    assert_equal 201, status, body
    record = Ideasbugs::Feedback.find_by!(tenant: 'upload', message: 'upload')
    assert_equal bytes, record.screenshots.first.download
    assert_equal Digest::MD5.base64digest(bytes), record.screenshots.first.blob.checksum
  end

  def test_media_streams_through_the_authorized_engine_route
    skip 'Run with RACTOR_MEDIA=1 for Active Storage integration' unless defined?(ActiveStorage)

    bytes = 'ractor-media-bytes'
    record = Ideasbugs::Feedback.create!(message: 'media', kind: 'bug', tenant: 'media')
    record.screenshots.attach(io: StringIO.new(bytes), filename: 'pixel.png', content_type: 'image/png',
                              metadata: { analyzed: true })
    path = "/feedback/feedbacks/#{record.id}/screenshots/#{record.screenshots.first.id}"
    allowed = { 'HTTP_X_ADMIN' => 'yes', 'HTTP_X_TENANT' => 'media' }
    status, _, body = request('GET', path)
    assert_equal 403, status, body
    status, headers, body = request('GET', path, headers: allowed)
    assert_equal 200, status, body
    assert_equal bytes, body
    assert_includes headers['cache-control'], 'private'
    assert_includes headers['cache-control'], 'no-store'
  end

  def test_admin_status_update_preserves_record_url_generation
    record = Ideasbugs::Feedback.create!(kind: 'bug', message: 'triage', tenant: 'triage')
    headers = { 'HTTP_X_ADMIN' => 'yes', 'HTTP_X_TENANT' => 'triage' }
    status, response_headers, body = request('PATCH', "/feedback/feedbacks/#{record.id}",
                                             params: { feedback: { status: 'in_review' } }, headers: headers)
    assert_equal 303, status, body
    assert_equal "/feedback/feedbacks/#{record.id}", URI(response_headers.fetch('location')).path
    assert record.reload.in_review?
  end

  def test_host_model_feedback_resolver_runs_in_a_worker_ractor
    Ideasbugs::Feedback.create!(kind: 'bug', message: 'linked feedback', tenant: 'customer')
    count = Ractor.new do
      customer = RactorCustomer.new(tenant: 'customer')
      [customer.feedback.where(message: 'linked feedback').count,
       customer.parent_feedback.where(message: 'linked feedback').count]
    end.value
    assert_equal [1, 1], count
  end

  def test_default_global_id_feedback_resolver_runs_in_a_worker_ractor
    customer = RactorCustomer.new(id: 501)
    Ideasbugs::Feedback.create!(kind: 'bug', message: 'global feedback', tenant: customer.to_gid.to_s)
    count = Ractor.new do
      RactorCustomer.new(id: 501).global_feedback.where(message: 'global feedback').count
    end.value
    assert_equal 1, count
  end

  def test_simultaneous_worker_requests
    workers = 2.times.map { start_request('GET', '/feedback/widget.js') }
    workers.each do |worker|
      status, _, body = worker.value
      assert_equal 200, status, body
    end
  end

  def test_assets_and_dashboard_render_in_non_main_ractors
    2.times do
      status, headers, body = request('GET', '/feedback/widget.js')
      assert_equal 200, status, body
      assert_includes headers['content-type'], 'javascript'
      assert_includes body, 'ideasbugs'
      status, _, body = request('GET', '/feedback/dashboard.css')
      assert_equal 200, status, body
      status, _, body = request('GET', '/feedback')
      assert_equal 403, status, body
      status, _, body = request('GET', '/feedback', headers: { 'HTTP_X_ADMIN' => 'yes' })
      assert_equal 200, status, body
    end
  end

  def test_submissions_resolve_request_callbacks_and_keep_tenants_separate
    %w[alpha beta].each do |tenant|
      status, _, body = request('POST', '/feedback/feedbacks',
                                params: { feedback: { kind: 'bug', message: "Ractor #{tenant}" } },
                                headers: { 'HTTP_X_TENANT' => tenant, 'HTTP_X_USER' => tenant })
      assert_equal 201, status, body
      record = Ideasbugs::Feedback.find_by!(tenant: tenant, message: "Ractor #{tenant}")
      assert_equal tenant, record.author_id
      assert_equal 'ractor@example.com:notified', record.author_label
    end
    status, _, body = request('GET', '/feedback', headers: { 'HTTP_X_ADMIN' => 'yes', 'HTTP_X_TENANT' => 'alpha' })
    assert_equal 200, status, body
    assert_includes body, 'Ractor alpha'
    refute_includes body, 'Ractor beta'
    status, _, body = request('POST', '/feedback/feedbacks', params: { feedback: { message: 'blocked' } },
                                                             headers: { 'HTTP_X_DISABLED' => 'yes' })
    assert_equal 403, status, body
    refute Ideasbugs::Feedback.exists?(message: 'blocked')
  end
end
