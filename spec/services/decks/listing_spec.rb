require 'rails_helper'

RSpec.describe Decks::Listing, type: :service do
  let(:user) { create(:user) }

  def deck(name, **attrs)
    create(:collection, user: user, name: name, collection_type: 'commander_deck', is_public: true, **attrs)
  end

  def names(listing) = listing.decks.map(&:name)

  it 'sorts by the requested option and falls back to recently updated' do
    deck('B', updated_at: 2.days.ago)
    deck('A', updated_at: 1.day.ago)

    expect(names(described_class.call(user: user, viewer: user, sort: 'name_desc'))).to eq(%w[B A])
    expect(names(described_class.call(user: user, viewer: user, sort: 'nonsense'))).to eq(%w[A B])
  end

  it 'hides private decks from everyone but the owner' do
    deck('Open')
    deck('Secret', is_public: false)

    expect(names(described_class.call(user: user, viewer: user))).to contain_exactly('Open', 'Secret')
    expect(names(described_class.call(user: user, viewer: create(:user)))).to eq(['Open'])
  end

  it 'leaves out a deck that is being deleted, groups included' do
    keep = deck('Keep')
    gone = deck('Gone')

    listing = described_class.call(user: user, viewer: user, group_by: 'tag', exclude_id: gone.id)

    expect(listing.decks).to eq([keep])
    expect(listing.groups.flat_map(&:decks)).to eq([keep])
  end

  it 'ignores an unknown grouping' do
    expect(described_class.call(user: user, viewer: user, group_by: 'nope').group_by).to eq('none')
  end

  describe 'game tracker stats' do
    def games_for(collection, results, fun: nil)
      tracked = create(:tracked_deck, user: user, collection: collection)
      results.each { |won| create(:commander_game, user: user, tracked_deck: tracked, won: won, fun_rating: fun) }
    end

    it 'sorts by win rate, breaking ties on games played, with unplayed decks last' do
      deck('Unplayed', updated_at: 1.hour.ago)
      games_for(deck('Half'), [true, false])
      games_for(deck('Perfect'), [true])
      games_for(deck('Perfect Twice'), [true, true])

      expect(names(described_class.call(user: user, viewer: user, sort: 'win_rate_desc')))
        .to eq(['Perfect Twice', 'Perfect', 'Half', 'Unplayed'])
    end

    it 'sorts by fun rating, with decks that have no rated games last' do
      games_for(deck('Unrated'), [true])
      games_for(deck('Fun', updated_at: 2.days.ago), [false], fun: 9)
      games_for(deck('Meh', updated_at: 1.day.ago), [true], fun: 4)

      expect(names(described_class.call(user: user, viewer: user, sort: 'fun_desc'))).to eq(%w[Fun Meh Unrated])
    end

    it 'keeps stats and their sorts from other viewers while the tracker is private' do
      games_for(deck('Played'), [true])
      user.update!(game_tracker_public: false)

      listing = described_class.call(user: user, viewer: create(:user), sort: 'win_rate_desc')

      expect(listing.game_stats).to be_empty
      expect(listing.sort).to eq('updated_desc')
      expect(listing.sort_options).not_to have_key('win_rate_desc')
    end

    it 'shares stats once the tracker is public' do
      played = deck('Played')
      games_for(played, [true])
      user.update!(game_tracker_public: true)

      expect(described_class.call(user: user, viewer: create(:user)).game_stats.keys).to eq([played.id])
    end
  end
end
