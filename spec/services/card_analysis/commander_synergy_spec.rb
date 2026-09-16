require 'rails_helper'

RSpec.describe CardAnalysis::CommanderSynergy, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }
  let(:binder) { create(:collection, user: user, name: 'Binder') }
  let(:commander_legality) { Legality.find_or_create_by!(name: 'commander') }
  let(:green) { Color.find_or_create_by!(name: 'G') }
  let(:red) { Color.find_or_create_by!(name: 'R') }

  let(:commander) do
    card = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid, card_side: nil,
                               can_be_commander: true, card_type: 'Legendary Creature - Elf',
                               text: 'Sacrifice another creature: Prossh gets +1/+0.')
    MagicCardColorIdent.create!(magic_card: card, color: green)
    create(:card_role, scryfall_oracle_id: card.scryfall_oracle_id,
                       role: 'sacrifice', effect: 'sacrifice_outlet', confidence: 0.9)
    card
  end

  def candidate(role:, effect:, name: 'Candidate', **attrs)
    card = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid, card_side: nil,
                               name: name, edhrec_rank: attrs.fetch(:rank, 2500))
    MagicCardLegality.find_or_create_by!(magic_card: card, legality: commander_legality, status: 'Legal')
    attrs.fetch(:colors, []).each { |color| MagicCardColorIdent.create!(magic_card: card, color: color) }
    create(:card_role, scryfall_oracle_id: card.scryfall_oracle_id,
                       role: role, effect: effect, confidence: attrs.fetch(:confidence, 0.9))
    card
  end

  def synergy(**)
    described_class.call(commander: commander, user: user, owned_only: false, **)
  end

  def suggested_names(result)
    result[:buckets].flat_map { |bucket| bucket[:cards] }.map { |card| card[:magic_card].name }
  end

  describe 'themes' do
    it 'reads the commander own high confidence roles as targets' do
      expect(synergy[:themes][:role_weights]).to eq({ %w[sacrifice sacrifice_outlet] => 0.9 })
    end
  end

  describe 'gating' do
    it 'excludes candidates outside the commander colour identity' do
      candidate(role: 'ramp', effect: 'mana_dork', colors: [red], name: 'Off Colour')

      expect(suggested_names(synergy)).not_to include('Off Colour')
    end

    it 'includes candidates inside the commander colour identity' do
      candidate(role: 'ramp', effect: 'mana_dork', colors: [green], name: 'On Colour')

      expect(suggested_names(synergy)).to include('On Colour')
    end

    it 'excludes cards that are not commander legal' do
      card = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid, card_side: nil, name: 'Banned Thing')
      create(:card_role, scryfall_oracle_id: card.scryfall_oracle_id, role: 'ramp',
                         effect: 'mana_dork', confidence: 0.9)

      expect(suggested_names(synergy)).not_to include('Banned Thing')
    end

    # Below HIGH_CONFIDENCE the pattern rules are guessing, and a ranked list built on guesses is chaff.
    it 'excludes low confidence role matches' do
      candidate(role: 'ramp', effect: 'mana_dork', confidence: 0.5, name: 'Maybe Ramp')

      expect(suggested_names(synergy)).not_to include('Maybe Ramp')
    end

    it 'excludes basic lands' do
      candidate(role: 'manabase', effect: 'basic_land', name: 'Forest')

      expect(suggested_names(synergy)).not_to include('Forest')
    end

    it 'excludes cards already in the deck' do
      card = candidate(role: 'ramp', effect: 'mana_dork', name: 'Already Have It')
      create(:collection_magic_card, collection: deck, magic_card: card)

      expect(suggested_names(described_class.call(commander: commander, user: user, deck: deck,
                                                  owned_only: false))).not_to include('Already Have It')
    end
  end

  describe 'buckets' do
    it 'leads with the commander theme roles ahead of the generic checklist' do
      candidate(role: 'sacrifice', effect: 'sacrifice_outlet', name: 'Sac Outlet')
      candidate(role: 'ramp', effect: 'mana_dork', name: 'A Dork')

      expect(synergy[:buckets].first[:role]).to eq('sacrifice')
    end

    it 'carries the deck target for a checklist role' do
      candidate(role: 'ramp', effect: 'mana_dork')

      ramp = synergy[:buckets].find { |bucket| bucket[:role] == 'ramp' }
      expect(ramp[:target]).to eq(10)
    end

    it 'counts what the deck already has toward the target' do
      in_deck = candidate(role: 'ramp', effect: 'mana_dork', name: 'In The Deck')
      create(:collection_magic_card, collection: deck, magic_card: in_deck)
      candidate(role: 'ramp', effect: 'mana_rock', name: 'Suggestion')

      result = described_class.call(commander: commander, user: user, deck: deck, owned_only: false)
      expect(result[:buckets].find { |bucket| bucket[:role] == 'ramp' }[:in_deck]).to eq(1)
    end

    it 'puts each card in exactly one bucket' do
      card = candidate(role: 'ramp', effect: 'mana_dork', name: 'Does Two Things')
      create(:card_role, scryfall_oracle_id: card.scryfall_oracle_id,
                         role: 'card_draw', effect: 'draw', confidence: 0.9)

      expect(suggested_names(synergy).count('Does Two Things')).to eq(1)
    end

    it 'narrows to a single bucket when a role is given' do
      candidate(role: 'ramp', effect: 'mana_dork')
      candidate(role: 'removal', effect: 'bounce')

      expect(synergy(role: 'ramp')[:buckets].pluck(:role)).to eq(['ramp'])
    end

    it 'caps each bucket at the limit' do
      3.times { |i| candidate(role: 'ramp', effect: 'mana_dork', name: "Dork #{i}") }

      expect(synergy(limit: 2)[:buckets].first[:cards].size).to eq(2)
    end
  end

  describe 'ownership' do
    it 'flags a card you own in another collection and names the collection' do
      card = candidate(role: 'ramp', effect: 'mana_dork', name: 'Owned Dork')
      create(:collection_magic_card, collection: binder, magic_card: card, quantity: 2)

      entry = synergy[:buckets].flat_map { |b| b[:cards] }.find { |c| c[:magic_card].name == 'Owned Dork' }
      expect(entry[:owned]).to be true
      expect(entry[:sources].first[:collection_name]).to eq('Binder')
      expect(entry[:sources].first[:available]).to eq(2)
    end

    it 'sorts owned cards ahead of a better scoring unowned card' do
      owned = candidate(role: 'ramp', effect: 'mana_dork', confidence: 0.7, name: 'Owned Dork')
      create(:collection_magic_card, collection: binder, magic_card: owned, quantity: 1)
      candidate(role: 'ramp', effect: 'mana_dork', confidence: 1.0, name: 'Better Unowned')

      ramp = synergy[:buckets].find { |bucket| bucket[:role] == 'ramp' }
      expect(ramp[:cards].first[:magic_card].name).to eq('Owned Dork')
    end

    it 'returns only owned cards when owned_only is set' do
      owned = candidate(role: 'ramp', effect: 'mana_dork', name: 'Owned Dork')
      create(:collection_magic_card, collection: binder, magic_card: owned, quantity: 1)
      candidate(role: 'ramp', effect: 'mana_dork', name: 'Unowned Dork')

      names = suggested_names(described_class.call(commander: commander, user: user, owned_only: true))
      expect(names).to eq(['Owned Dork'])
    end
  end

  describe 'ranking' do
    # Fit leads: a card has to actually do the thing before being interesting for being unplayed.
    it 'ranks a theme match above a generic role match' do
      candidate(role: 'sacrifice', effect: 'sacrifice_outlet', name: 'On Theme')
      candidate(role: 'ramp', effect: 'mana_dork', name: 'Off Theme')

      result = synergy
      on_theme = result[:buckets].flat_map { |b| b[:cards] }.find { |c| c[:magic_card].name == 'On Theme' }
      off_theme = result[:buckets].flat_map { |b| b[:cards] }.find { |c| c[:magic_card].name == 'Off Theme' }

      expect(on_theme[:raw_fit]).to be > off_theme[:raw_fit]
    end

    # The failure this whole band exists to prevent: rank-27,000 cards are unplayed because they are bad.
    it 'ranks a mid-rank card above bulk with the same role match' do
      candidate(role: 'ramp', effect: 'mana_dork', rank: 2500, name: 'Overlooked')
      candidate(role: 'ramp', effect: 'mana_dork', rank: 29_000, name: 'Actual Bulk')

      ramp = synergy[:buckets].find { |bucket| bucket[:role] == 'ramp' }
      expect(ramp[:cards].map { |c| c[:magic_card].name }).to eq(['Overlooked', 'Actual Bulk'])
    end

    it 'ranks a mid-rank card above a format staple with the same role match' do
      candidate(role: 'ramp', effect: 'mana_dork', rank: 2500, name: 'Overlooked')
      candidate(role: 'ramp', effect: 'mana_dork', rank: 1, name: 'Everyone Runs It')

      ramp = synergy[:buckets].find { |bucket| bucket[:role] == 'ramp' }
      expect(ramp[:cards].map { |c| c[:magic_card].name }).to eq(['Overlooked', 'Everyone Runs It'])
    end

    it 'reports the matched roles that earned the score' do
      candidate(role: 'sacrifice', effect: 'sacrifice_outlet', name: 'On Theme')

      entry = synergy[:buckets].first[:cards].first
      expect(entry[:matched_roles]).to include({ role: 'sacrifice', effect: 'sacrifice_outlet' })
    end
  end

  # The precon corpus supplies the quality signal card_roles cannot: inside a generic bucket every
  # candidate scores nearly the same on fit, so this is what breaks the tie.
  describe 'the precon signals' do
    def precon_with(cards)
      deck = create(:precon_deck, deck_type: 'Commander Deck')
      PreconDeckCard.create!(precon_deck: deck, magic_card: commander, board_type: 'commander')
      cards.each { |c| PreconDeckCard.create!(precon_deck: deck, magic_card: c, board_type: 'mainBoard') }
      deck
    end

    def card_named(result, name)
      result[:buckets].flat_map { |bucket| bucket[:cards] }.find { |card| card[:magic_card].name == name }
    end

    it 'reports how many precons a suggestion appears in' do
      printed = candidate(role: 'ramp', effect: 'mana_dork', colors: [green], name: 'Printed')
      2.times { precon_with([printed]) }

      expect(card_named(synergy, 'Printed')[:precon_decks]).to eq(2)
    end

    it 'reports zero for a card no precon has ever run' do
      candidate(role: 'ramp', effect: 'mana_dork', colors: [green], name: 'Never Printed')

      entry = card_named(synergy, 'Never Printed')
      expect(entry[:precon_decks]).to eq(0)
      expect(entry[:precon]).to eq(0.0)
    end

    it 'ranks a card designers reach for above an identical one they do not' do
      printed = candidate(role: 'ramp', effect: 'mana_dork', colors: [green], name: 'Printed')
      candidate(role: 'ramp', effect: 'mana_dork', colors: [green], name: 'Never Printed')
      3.times { precon_with([printed]) }

      ramp = synergy[:buckets].find { |bucket| bucket[:role] == 'ramp' }
      expect(ramp[:cards].map { |card| card[:magic_card].name }).to eq(['Printed', 'Never Printed'])
    end

    # Co-occurrence is anchored on the deck's own cards, so a deck that is still just a commander has
    # nothing to measure against.
    it 'scores co-occurrence at zero when the deck has no cards yet' do
      printed = candidate(role: 'ramp', effect: 'mana_dork', colors: [green], name: 'Printed')
      precon_with([printed])

      expect(card_named(synergy, 'Printed')[:cooccurrence]).to eq(0.0)
    end

    it 'lifts a card that shares precons with what is already in the deck' do
      in_deck = candidate(role: 'ramp', effect: 'mana_dork', colors: [green], name: 'Already Here')
      travels = candidate(role: 'ramp', effect: 'mana_dork', colors: [green], name: 'Travels With It')
      loner = candidate(role: 'ramp', effect: 'mana_dork', colors: [green], name: 'Loner')

      3.times { precon_with([in_deck, travels]) }
      3.times { precon_with([loner]) }
      create(:collection_magic_card, collection: deck, magic_card: in_deck)

      result = described_class.call(commander: commander, user: user, deck: deck, owned_only: false)
      ramp = result[:buckets].find { |bucket| bucket[:role] == 'ramp' }

      expect(card_named(result, 'Travels With It')[:cooccurrence]).to be > 0.0
      expect(ramp[:cards].first[:magic_card].name).to eq('Travels With It')
    end
  end

  # Read off the deck's last Spellbook check: an almost_included combo whose one missing card you own.
  describe 'combo pieces' do
    let(:combo_role) { described_class::COMBO_ROLE }

    def legal_card(name)
      card = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid, card_side: nil, name: name, edhrec_rank: 2500)
      MagicCardLegality.find_or_create_by!(magic_card: card, legality: commander_legality, status: 'Legal')
      card
    end

    def one_card_short(card, results: 'Infinite mana')
      combo = Combo.create!(spellbook_id: SecureRandom.hex(4), results: results)
      deck_combo = DeckCombo.create!(collection: deck, combo: combo, combo_type: 'almost_included')
      deck_combo.deck_combo_missing_cards.create!(card_name: card.name, oracle_id: card.scryfall_oracle_id)
    end

    def own(card)
      create(:collection_magic_card, collection: binder, magic_card: card, quantity: 1)
    end

    def with_deck(**)
      described_class.call(commander: commander, user: user, deck: deck, owned_only: false, **)
    end

    it 'leads with an owned card that completes a combo' do
      piece = legal_card('Combo Piece')
      own(piece)
      2.times { |i| one_card_short(piece, results: "Result #{i}") }
      candidate(role: 'ramp', effect: 'mana_dork', name: 'A Dork')

      bucket = with_deck[:buckets].first
      expect(bucket[:role]).to eq(combo_role)
      expect(bucket[:cards].first).to include(combo_count: 2, combo_results: ['Result 0', 'Result 1'])
      expect(bucket[:cards].first[:magic_card].name).to eq('Combo Piece')
    end

    it 'does not suggest a combo piece you do not own' do
      one_card_short(legal_card('Unowned Piece'))

      expect(suggested_names(with_deck)).not_to include('Unowned Piece')
    end

    it 'moves a piece out of its role bucket but keeps its roles' do
      piece = candidate(role: 'ramp', effect: 'mana_dork', name: 'Dork And Piece')
      own(piece)
      one_card_short(piece)

      result = with_deck
      expect(suggested_names(result).count('Dork And Piece')).to eq(1)
      card = result[:buckets].find { |bucket| bucket[:role] == combo_role }[:cards].first
      expect(card[:matched_roles]).to include({ role: 'ramp', effect: 'mana_dork' })
    end

    it 'narrows to the combo bucket when that role is given' do
      piece = legal_card('Combo Piece')
      own(piece)
      one_card_short(piece)
      candidate(role: 'ramp', effect: 'mana_dork')

      expect(with_deck(role: combo_role)[:buckets].pluck(:role)).to eq([combo_role])
    end

    it 'offers no combo filter without a deck' do
      expect(synergy[:roles]).not_to include(combo_role)
    end
  end

  it 'returns no buckets when nothing matches' do
    expect(synergy[:buckets]).to be_empty
  end
end
