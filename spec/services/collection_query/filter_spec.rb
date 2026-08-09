require 'rails_helper'

RSpec.describe CollectionQuery::Filter, type: :service do
  let(:boxset) { create(:boxset, code: 'TST') }
  let!(:rare_card) { create(:magic_card, rarity: 'rare', boxset: boxset) }
  let!(:common_card) { create(:magic_card, rarity: 'common', boxset: create(:boxset)) }

  let(:cards) { MagicCard.all }

  context 'when filtering by rarity' do
    it 'returns only matching rarities' do
      result = described_class.call(cards: cards, rarities: ['rare'])
      expect(result).to include(rare_card)
      expect(result).not_to include(common_card)
    end
  end

  context 'when filtering by boxset code' do
    it 'returns only cards from that boxset' do
      result = described_class.call(cards: cards, code: 'TST')
      expect(result).to include(rare_card)
      expect(result).not_to include(common_card)
    end
  end

  context 'when filtering by price change range' do
    before do
      rare_card.update_column(:price_change_weekly_normal, 15.0)
      common_card.update_column(:price_change_weekly_normal, 2.0)
    end

    it 'filters cards within the price change range' do
      result = described_class.call(cards: cards, price_change_min: 10.0, price_change_max: 20.0)
      expect(result).to include(rare_card)
      expect(result).not_to include(common_card)
    end
  end

  context 'with no filters applied' do
    it 'returns all cards' do
      result = described_class.call(cards: cards)
      expect(result.count).to eq(cards.count)
    end
  end

  # the grouped, owned-price ordered relation the collections controller filters - the branches
  # below only behave differently on this shape, which the MagicCard.all cases above never reach
  context 'on the grouped collections relation' do
    let(:user) { create(:user) }
    let(:collection) { create(:collection, user: user) }
    let(:red) { Color.find_or_create_by!(name: 'R') }
    let(:white) { Color.find_or_create_by!(name: 'W') }

    let!(:red_white) { create(:magic_card, name: 'Boros Charm') }
    let!(:mono_red) { create(:magic_card, name: 'Shock') }
    let!(:colorless) { create(:magic_card, name: 'Sol Ring') }

    let(:grouped) do
      Search::Collection.call(
        cards: MagicCard.joins(collection_magic_cards: :collection).where(collections: { user_id: user.id }),
        search_term: '', sort_by: :price
      )
    end

    before do
      MagicCardColor.create!(magic_card: red_white, color: red)
      MagicCardColor.create!(magic_card: red_white, color: white)
      MagicCardColor.create!(magic_card: mono_red, color: red)
      [red_white, mono_red, colorless].each do |card|
        create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1)
      end
    end

    def quantity_for(relation, card)
      relation.detect { |row| row.id == card.id }&.quantity.to_i
    end

    context 'when filtering by colors' do
      it 'returns the cards carrying any of the selected colors' do
        result = described_class.call(cards: grouped, colors: %w[R])

        expect(result.map(&:name)).to match_array(['Boros Charm', 'Shock'])
      end

      # a join would fan a card out to one row per matching color, and the relation is grouped,
      # so SUM(quantity) counted a two-color card once per color it matched
      it 'does not inflate the quantity of a card matching more than one selected color' do
        result = described_class.call(cards: grouped, colors: %w[R W])

        expect(quantity_for(result, red_white)).to eq(1)
        expect(quantity_for(result, mono_red)).to eq(1)
      end

      # DISTINCT made the aggregate owned-price ORDER BY illegal, which 500'd the default sort
      it 'leaves the relation free of DISTINCT so the aggregate ordering stays legal' do
        result = described_class.call(cards: grouped, colors: %w[R])

        expect(result.distinct_value).to be_falsey
        expect { result.load }.not_to raise_error
      end

      it 'returns only cards with no colors for C' do
        result = described_class.call(cards: grouped, colors: %w[C])

        expect(result.map(&:name)).to eq(['Sol Ring'])
      end

      it 'returns only cards whose colors match exactly when exact_color_match is set' do
        result = described_class.call(cards: grouped, colors: %w[R], exact_color_match: true)

        expect(result.map(&:name)).to eq(['Shock'])
      end
    end

    context 'when hiding proxies' do
      let!(:proxy_only) { create(:magic_card, name: 'Black Lotus') }

      before do
        create(:collection_magic_card, collection: collection, magic_card: proxy_only,
                                       quantity: 0, foil_quantity: 0, proxy_quantity: 1)
      end

      it 'drops rows the user owns no real copies of' do
        result = described_class.call(cards: grouped, hide_proxies: true)

        expect(result.map(&:name)).not_to include('Black Lotus')
      end

      it 'keeps them when proxies are shown' do
        result = described_class.call(cards: grouped, hide_proxies: false)

        expect(result.map(&:name)).to include('Black Lotus')
      end

      # the HAVING has nowhere to attach without the GROUP BY, so it bails rather than erroring
      it 'is a no-op on an ungrouped relation' do
        expect(described_class.call(cards: MagicCard.all, hide_proxies: true).map(&:name))
          .to include('Black Lotus')
      end
    end
  end

  context 'when parsing from params' do
    it 'parses rarity from params' do
      result = described_class.call(
        cards: cards,
        params: { rarity: ['rare'] }
      )
      expect(result).to include(rare_card)
      expect(result).not_to include(common_card)
    end

    it 'parses price change range from params' do
      rare_card.update_column(:price_change_weekly_normal, 15.0)
      result = described_class.call(
        cards: cards,
        params: { price_change_range: '10.0,20.0' }
      )
      expect(result).to include(rare_card)
    end
  end
end
