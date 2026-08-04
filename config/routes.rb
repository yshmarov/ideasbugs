# frozen_string_literal: true

Ideasbugs::Engine.routes.draw do
  # The widget code, served same-origin (see WidgetsController for why).
  get 'widget.js', to: 'widgets#show', as: :widget
  get 'dashboard.css', to: 'widgets#dashboard_stylesheet', as: :dashboard_stylesheet

  # POST goes to SubmissionsController, not to this resource: the widget's write
  # endpoint is public and the rest is staff-only, and only the staff half
  # inherits config.base_controller_class. Sharing one controller would put a
  # host's admin authentication in front of someone filing a report.
  post 'feedbacks', to: 'submissions#create', as: :submissions
  resources :feedbacks, only: %i[index show update destroy] do
    # Screenshots stream through the dashboard's own gate, never via public
    # Active Storage blob URLs.
    resources :screenshots, only: :show
  end

  root to: 'feedbacks#index'
end
