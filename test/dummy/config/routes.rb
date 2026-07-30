# frozen_string_literal: true

Rails.application.routes.draw do
  mount_ideasbugs at: "/feedback"
  get "sample", to: "sample#show"
end
