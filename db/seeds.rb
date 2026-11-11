# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Dev only: bot users with API tokens and a Commander deck each, for the game client's bin/net-bot.
# Tokens are printed once, on the run that issues them (see docs/dev_seeds.md).
if Rails.env.development?
  DevSeeds::NetBots.call.each do |bot|
    puts "net-bot: #{bot.user.username} deck=#{bot.deck&.name || 'none (no Commander precons ingested)'} " \
         "token=#{bot.token || 'already issued'}"
  end
end
