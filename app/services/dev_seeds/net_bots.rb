module DevSeeds
  # Bot users for bin/net-bot, so one machine can Host and join a Room as distinct users (the Relay keys on
  # the user). Each gets a Commander precon imported as a deck, which is a legal Commander list. Safe to
  # re-run: users and decks are found by name, and a token is only issued to a bot with no active one.
  # Raw tokens are never stored, so they appear in the result only on the run that issued them.
  class NetBots < Service
    BOT_COUNT = 3
    TOKEN_NAME = 'net-bot'.freeze
    DECK_TYPE = 'commander_deck'.freeze

    Bot = Struct.new(:user, :token, :deck, keyword_init: true)

    def initialize(count: BOT_COUNT)
      @count = count
    end

    def call
      raise 'DevSeeds::NetBots must never run in production' if Rails.env.production?

      precons = PreconDeck.commander_decks.order(:id).limit(@count).to_a
      Array.new(@count) { |index| seed_bot(index + 1, precons[index]) }
    end

    private

    def seed_bot(number, precon)
      user = find_or_create_user(number)
      Bot.new(user: user, token: issue_token(user), deck: precon && find_or_import_deck(user, precon))
    end

    def find_or_create_user(number)
      username = "net-bot-#{number}"
      User.find_or_create_by!(username: username) do |user|
        user.email = "#{username}@net-bot.invalid"
        user.password = SecureRandom.hex(16)
        user.confirmed_at = Time.current
      end
    end

    def issue_token(user)
      return if user.api_tokens.active.exists?(name: TOKEN_NAME)

      _record, raw_token = ApiToken.issue!(user, name: TOKEN_NAME)
      raw_token
    end

    def find_or_import_deck(user, precon)
      existing = user.collections.find_by(name: precon.name, collection_type: DECK_TYPE)
      return existing if existing

      deck = user.collections.create!(name: precon.name, collection_type: DECK_TYPE,
                                      description: precon.import_description)
      PreconDeckImporter.call(precon_deck: precon, collection: deck)
      deck
    end
  end
end
