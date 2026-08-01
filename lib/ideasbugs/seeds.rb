# frozen_string_literal: true

module Ideasbugs
  module Seeds
    FEEDBACK = [
      {
        seed_id: 'checkout-error',
        kind: 'bug',
        section: 'Checkout',
        message: 'The payment form shows "Something went wrong" after entering a valid card.',
        status: 'open',
        page_url: '/checkout',
        author_label: 'Demo Customer'
      },
      {
        seed_id: 'saved-filters',
        kind: 'feature',
        section: 'Reports',
        message: 'It would save time if I could save this report filter and reuse it next week.',
        status: 'in_review',
        page_url: '/reports/revenue',
        author_label: 'Demo Product Manager'
      },
      {
        seed_id: 'export-confusing',
        kind: 'other',
        section: 'Settings',
        message: 'The CSV export worked, but I expected the button to say when the file was ready.',
        status: 'resolved',
        page_url: '/settings/exports',
        author_label: 'Demo Admin'
      }
    ].freeze

    def self.load!(tenant: nil)
      FEEDBACK.map do |attributes|
        seed_id = attributes.fetch(:seed_id)
        feedback = Ideasbugs::Feedback.find_or_initialize_by(
          author_id: "ideasbugs-demo:#{seed_id}",
          tenant: tenant.presence
        )
        feedback.assign_attributes(attributes.except(:seed_id).merge(
          kind: kind_for(attributes.fetch(:kind)),
          tenant: tenant.presence,
          user_agent: 'ideasbugs demo seed'
        ))
        feedback.save!
        feedback
      end
    end

    def self.kind_for(preferred)
      kinds = Ideasbugs.config.kinds.map(&:to_s)
      return preferred if kinds.include?(preferred)
      return kinds.first if kinds.any?

      preferred
    end
    private_class_method :kind_for
  end
end
