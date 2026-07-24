# frozen_string_literal: true

Rails.application.routes.draw do
  mount FeedbackEngine::Engine => "/feedback"
  get "sample", to: "sample#show"
end
