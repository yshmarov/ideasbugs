# frozen_string_literal: true

Ideasbugs::Engine.routes.draw do
  # The widget code, served same-origin (see WidgetsController for why).
  get 'widget.js', to: 'widgets#show', as: :widget
  get 'dashboard.css', to: 'widgets#dashboard_stylesheet', as: :dashboard_stylesheet

  # create is the public widget endpoint; the rest is the triage dashboard.
  resources :feedbacks, only: %i[create index show update destroy] do
    # Screenshots stream through the dashboard's own gate, never via public
    # Active Storage blob URLs.
    resources :screenshots, only: :show
  end

  root to: 'feedbacks#index'
end
