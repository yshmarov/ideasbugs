# frozen_string_literal: true

class SampleController < ActionController::Base
  def show
    render inline: <<~ERB
      <!DOCTYPE html>
      <html>
        <head><meta name="csrf-token" content="test"></head>
        <body>
          <h1>Sample page</h1>
          <a href="#" id="custom-opener" data-feedback-engine-open>Give feedback</a>
          <%= feedback_engine_tag %>
        </body>
      </html>
    ERB
  end
end
