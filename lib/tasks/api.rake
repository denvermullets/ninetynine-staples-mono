namespace :api do
  # bin/rails "api:export_fixtures[18 17,2534]" - deck ids space-separated, then an optional Commander
  # precon id (the newest one by default). Writes tmp/api_fixtures/*.json plus the schemas, for the game
  # client repo's tests/fixtures/api/
  desc 'Export real /api/v1 responses as game client test fixtures'
  task :export_fixtures, %i[deck_ids precon_id] => :environment do |_, args|
    require_relative 'api_fixture_exporter'

    out_dir = Rails.root.join('tmp/api_fixtures')
    index = ApiFixtureExporter.new(deck_ids: args[:deck_ids].to_s.split, precon_id: args[:precon_id],
                                   out_dir: out_dir).call
    index.each { |file, schema| puts "#{file.ljust(28)} #{schema}" }
    puts "Wrote #{index.size} fixtures and the schemas to #{out_dir}"
  end
end
