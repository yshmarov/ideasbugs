# frozen_string_literal: true

namespace :ideasbugs do
  desc 'Create or refresh ideasbugs demo feedback'
  task seed_demo: :environment do
    feedback = Ideasbugs::Seeds.load!
    puts "Seeded #{feedback.size} ideasbugs demo feedback records."
  end
end
