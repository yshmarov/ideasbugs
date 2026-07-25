# frozen_string_literal: true

Rails.application.routes.draw do
  mount Ideasbugs::Engine => "/feedback"
  get "sample", to: "sample#show"
end
