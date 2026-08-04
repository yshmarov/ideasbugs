# frozen_string_literal: true

require_relative 'lib/ideasbugs/version'

Gem::Specification.new do |spec|
  spec.name = 'ideasbugs'
  spec.version = Ideasbugs::VERSION
  spec.authors = ['Yaroslav Shmarov']
  spec.email = ['yaroslav.shmarov@clickfunnels.com']

  spec.summary = 'In-app product feedback collection for Rails: a drop-in widget and a built-in triage dashboard.'
  spec.description = <<~DESC
    A mountable Rails engine that adds a "Send feedback" widget to your app —
    bug reports, feature requests, screenshots — and stores submissions in your
    own database. Ships with a minimal built-in dashboard to browse and triage
    what users send. Framework-agnostic: no CSS or JS framework required.
  DESC
  spec.homepage = 'https://github.com/yshmarov/ideasbugs'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir[
    'app/**/*',
    'config/**/*',
    'lib/**/*',
    'MIT-LICENSE',
    'Rakefile',
    'README.md',
    'CHANGELOG.md',
    # Ships so an agent working in a host app can read the install guide
    # straight out of the bundle: `cat "$(bundle show ideasbugs)/AGENTS.md"`.
    'AGENTS.md'
  ]
  spec.require_paths = ['lib']

  spec.add_dependency 'rails', '>= 7.1'
end
