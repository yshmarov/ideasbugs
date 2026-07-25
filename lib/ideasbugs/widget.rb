# frozen_string_literal: true

require 'json'
require 'digest'

module Ideasbugs
  # Serves the self-contained browser widget. The JavaScript is plain ES (no
  # framework, no build step) and styles itself inline, so it drops into any
  # Rails app regardless of its CSS or JS setup. It is served by the engine's
  # own controller rather than through the host's asset pipeline, so there is
  # no dependency on it — and it lives under lib/ (not app/assets/) so a host
  # that *does* run a pipeline never ingests it either: nothing lands in the
  # host's asset namespace or precompiled output.
  module Widget
    SOURCE = File.expand_path('widget.js', __dir__)

    # Right-to-left scripts, so the form renders mirrored for those locales.
    # Matched on the language subtag, so region variants ("ar-EG") count too.
    RTL_LANGUAGES = %w[ar arc ckb dv fa ha he ks ku ps sd ug ur yi].freeze

    class << self
      def javascript
        @javascript ||= File.read(SOURCE)
      end

      # Content fingerprint for the cache-busting script URL: a changed file
      # is a changed URL, so no browser can ever run stale widget code —
      # Safari has been caught ignoring must-revalidate on same-URL scripts.
      def fingerprint
        @fingerprint ||= Digest::MD5.hexdigest(javascript)
      end

      # The two <script> tags the helper renders.
      #
      # The config rides in a `type="application/json"` block: it is *data*,
      # not code, so the browser never executes it and Turbo never tries to
      # re-run it on a soft visit — which means it needs no CSP nonce and the
      # widget can re-read the *current* page's config on every `turbo:load`.
      #
      # The code is a same-origin `src` script served by the engine — NOT
      # inlined. Under a nonce-based CSP, Turbo Drive body swaps re-run body
      # scripts against the *original* page's CSP header, so a fresh inline
      # nonce gets refused; a same-origin src is covered by `'self'` on every
      # visit. `nonce:` is still stamped for hosts whose script-src has no
      # 'self'; pass nil when the app has no nonce.
      def snippet(endpoint:, locale:, nonce: nil)
        config = {
          endpoint: endpoint,
          locale: locale.to_s,
          kinds: kinds,
          sections: Ideasbugs.config.sections.map(&:to_s),
          screenshots: screenshots,
          showButton: Ideasbugs.config.show_button ? true : false,
          buttonLabel: Ideasbugs.config.button_label,
          labels: labels,
          rtl: rtl?(locale)
        }
        # Escape "</" so a value can't close the <script> block early.
        json = config.to_json.gsub('</', '<\/')
        nonce_attr = nonce ? %( nonce="#{nonce}") : ''
        src = "#{Ideasbugs.config.mount_path.chomp('/')}/widget.js?v=#{fingerprint}"

        %(<script type="application/json" data-ideasbugs-config>#{json}</script>) +
          %(<script src="#{src}" defer#{nonce_attr} data-ideasbugs-widget></script>)
      end

      private

      def kinds
        Ideasbugs.config.kinds.map do |kind|
          { value: kind.to_s, label: t("kinds.#{kind}", kind.to_s.humanize) }
        end
      end

      def screenshots
        {
          enabled: Ideasbugs.config.screenshots_enabled?,
          max: Ideasbugs.config.max_screenshots,
          maxSize: Ideasbugs.config.max_screenshot_size
        }
      end

      # Every user-facing string in the widget, resolved through Rails I18n so
      # the form follows the app's current locale. Each lookup carries an
      # English default, so the widget stays fully worded even when the host is
      # missing a key for the active locale.
      def labels
        {
          button: t(:button, 'Feedback'),
          title: t(:title, 'Send feedback'),
          kind: t(:kind, 'Type'),
          section: t(:section, 'Section'),
          sectionAny: t(:section_any, 'General'),
          message: t(:message, 'Your message'),
          messagePlaceholder: t(:message_placeholder, "Tell us what's on your mind…"),
          screenshots: t(:screenshots, 'Screenshots'),
          screenshotsHint: t(:screenshots_hint, 'optional, up to %{count} files, %{size} MB each',
                             count: Ideasbugs.config.max_screenshots,
                             size: Ideasbugs.config.max_screenshot_size / (1024 * 1024)),
          submit: t(:submit, 'Send feedback'),
          cancel: t(:cancel, 'Cancel'),
          close: t(:close, 'Close'),
          thanks: t(:thanks, 'Thanks for your feedback!'),
          errorBlank: t(:error_blank, 'Please enter a message.'),
          errorSave: t(:error_save, 'Could not send feedback. Please try again.'),
          errorTooMany: t(:error_too_many, 'Too many screenshots (max %{count}).',
                          count: Ideasbugs.config.max_screenshots),
          errorTooLarge: t(:error_too_large, 'A screenshot is too large (max %{size} MB).',
                           size: Ideasbugs.config.max_screenshot_size / (1024 * 1024))
        }
      end

      def t(key, default, **args)
        I18n.t(key, scope: :ideasbugs, default: default, **args)
      end

      def rtl?(locale)
        RTL_LANGUAGES.include?(locale.to_s.downcase.split(/[-_]/).first)
      end
    end
  end
end
