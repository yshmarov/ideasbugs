# frozen_string_literal: true

module Ideasbugs
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
