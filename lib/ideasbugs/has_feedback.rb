# frozen_string_literal: true

module Ideasbugs
  # Optional sugar for multi-tenant apps. `has_feedback` on a host model gives
  # it a `.feedback` relation, keyed by the record's GlobalID — the documented
  # tenant convention:
  #
  #   class Customer < ApplicationRecord
  #     has_feedback
  #   end
  #   customer.feedback.open   # a normal Active Record relation
  #
  # It's a pure veneer over `Feedback.for_tenant(...)` — no association, no
  # foreign key, no `owner_type` class-name coupling. Apps that don't want it
  # still get full multi-tenancy through `config.tenant` alone.
  #
  # The write side lines up automatically when the tenant resolver produces the
  # same GlobalID key, e.g. `config.tenant = ->(r){ Current.customer.to_gid.to_s }`.
  # Key by something else? Pass a matching resolver: `has_feedback(key:
  # ->(c){ c.subdomain })` — and use the same in `config.tenant`.
  module HasFeedback
    def has_feedback(as: :feedback, key: nil) # rubocop:disable Naming/PredicatePrefix
      resolver = key || ->(record) { record.to_gid.to_s }

      class_attribute :_ideasbugs_feedback_resolvers, instance_accessor: false, default: {} unless
        respond_to?(:_ideasbugs_feedback_resolvers)
      feedback_name = as.to_sym
      declaring_model = self
      self._ideasbugs_feedback_resolvers = _ideasbugs_feedback_resolvers.merge(feedback_name => resolver)
      getter = proc do
        key_resolver = declaring_model._ideasbugs_feedback_resolvers.fetch(feedback_name)
        Ideasbugs::Feedback.for_tenant(key_resolver.call(self))
      end
      getter = Ractor.shareable_proc(&getter) if defined?(Ractor.shareable_proc)
      define_method(as, &getter)
    end
  end
end
