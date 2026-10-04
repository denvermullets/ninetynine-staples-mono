require Rails.root.join('spec/support/api/schemas').to_s

# Writes real /api/v1 responses to JSON files for the game client's tests, its GameBuilder and the API
# client's mock mode, so the client can be built and tested without a running server. Every file is
# checked against its schema in spec/support/schemas before it is written, and the schemas are copied
# beside the fixtures (schemas/) so both go to the client together.
#
# Responses come from the app itself, in process, through a token issued for each deck's owner and
# deleted afterwards. The signed-in user is scrubbed: fixed id, username and email, default preferences.
class ApiFixtureExporter
  SCRUBBED_USER = { 'id' => 1, 'username' => 'player', 'email' => 'player@example.com' }.freeze
  TOKEN_NAME = 'Fixture export'.freeze
  # stands in for a real token in the login fixture
  FIXTURE_TOKEN = "#{ApiToken::PREFIX}fixture-token-not-valid-anywhere".freeze
  UNKNOWN_ID = '00000000-0000-0000-0000-000000000000'.freeze

  def initialize(deck_ids:, precon_id: nil, out_dir: Rails.root.join('tmp/api_fixtures'))
    @decks = Collection.decks.find(Array(deck_ids))
    raise ArgumentError, 'Pass at least one deck id' if @decks.empty?

    @precon = precon_id.present? ? PreconDeck.commander_decks.find(precon_id) : newest_precon
    @out_dir = Pathname(out_dir)
    @tokens = {}
  end

  # -> { file name => schema it matches }, also written to index.json
  def call
    reset_out_dir
    index = export_all
    write('index.json', index)
    FileUtils.cp_r(ApiSchemas::DIR, @out_dir.join('schemas'))
    index
  ensure
    @tokens.each_value { |(token, _)| token.destroy }
  end

  private

  def export_all
    owner = @decks.first.user
    [*account_fixtures(owner), *deck_fixtures(owner), *card_fixtures(owner)].to_h do |file, schema, data|
      [file, write_checked(file, schema, data)]
    end
  end

  # [[file, schema, data]]. A schema is a schema name, or { page_of: name } for a list endpoint
  def account_fixtures(owner)
    [['health.json', 'health', get_json('/api/v1/health', owner)],
     ['session.json', 'session', session_json(owner)],
     ['me.json', 'user', scrub_user(get_json('/api/v1/me', owner))],
     ['error_not_found.json', 'error', get_json('/api/v1/decks/0', owner, status: 404)]]
  end

  def deck_fixtures(owner)
    [['decks.json', { page_of: 'deck_summary' }, get_json('/api/v1/decks', owner, per_page: 100)],
     *@decks.map { |deck| ["deck_#{deck.id}.json", 'deck', get_json("/api/v1/decks/#{deck.id}", deck.user)] },
     ['precon_decks.json', { page_of: 'precon_deck_summary' }, get_json('/api/v1/precon_decks', owner)],
     ["precon_deck_#{@precon.id}.json", 'deck', get_json("/api/v1/precon_decks/#{@precon.id}", owner)]]
  end

  def card_fixtures(owner)
    [['cards_batch.json', 'card_batch', post_json('/api/v1/cards/batch', owner, oracle_ids: batch_ids)],
     ['tokens.json', { page_of: 'card' }, get_json('/api/v1/tokens', owner, per_page: 100)]]
  end

  def newest_precon
    PreconDeck.commander_decks.order(Arel.sql('release_date DESC NULLS LAST'), id: :desc).first!
  end

  # the commanders of every exported deck, by oracle id, plus one id that matches nothing so `missing`
  # has an example
  def batch_ids
    deck_rows = CollectionMagicCard.commanders.where(collection_id: @decks.map(&:id))
    commanders = MagicCard.where(id: deck_rows.select(:magic_card_id))
                          .or(MagicCard.where(id: @precon.precon_deck_cards.commanders.select(:magic_card_id)))
    [*commanders.pluck(:scryfall_oracle_id).compact.uniq.sort, UNKNOWN_ID]
  end

  # the login response, built the way SessionsController builds it, since logging in for real would need
  # the user's password
  def session_json(user)
    { 'token' => FIXTURE_TOKEN, 'expires_at' => ApiToken::LIFETIME.from_now.utc.iso8601(3),
      'user' => scrub_user(Api::V1::UserSerializer.new(user).as_json.stringify_keys) }
  end

  def scrub_user(json)
    json = json.merge(SCRUBBED_USER)
    json['preferences'] = UserPreferences::DEFAULT_PREFERENCES if json.key?('preferences')
    json
  end

  def get_json(path, user, status: 200, **params)
    parsed(request(:get, path, user, params: params), status)
  end

  def post_json(path, user, **body)
    parsed(request(:post, path, user, params: body.to_json, headers: { 'Content-Type' => 'application/json' }), 200)
  end

  def request(verb, path, user, params:, headers: {})
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.host! 'localhost'
    session.public_send(verb, path, params: params, headers: auth_headers(user).merge(headers))
    session.response
  end

  def parsed(response, status)
    raise "#{response.request.method} #{response.request.path} returned #{response.status}, expected #{status}" \
      unless response.status == status

    JSON.parse(response.body)
  end

  def auth_headers(user)
    _, raw_token = @tokens[user.id] ||= ApiToken.issue!(user, name: TOKEN_NAME)
    { 'Accept' => 'application/json', 'Authorization' => "Bearer #{raw_token}" }
  end

  # schema is a schema name or { page_of: item schema name }. Returns the index entry
  def write_checked(file, schema, data)
    errors = schema.is_a?(Hash) ? ApiSchemas.errors(data, **schema) : ApiSchemas.errors(data, schema)
    raise "#{file} does not match its schema:\n  #{errors.first(10).join("\n  ")}" if errors.any?

    write(file, data)
    schema.is_a?(Hash) ? "page of schemas/#{schema[:page_of]}.json" : "schemas/#{schema}.json"
  end

  def write(file, data)
    @out_dir.join(file).write("#{JSON.pretty_generate(data)}\n")
  end

  def reset_out_dir
    FileUtils.rm_rf(@out_dir)
    FileUtils.mkdir_p(@out_dir)
  end
end
