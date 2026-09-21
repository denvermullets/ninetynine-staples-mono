require 'rails_helper'

RSpec.describe 'Boxsets', type: :request do
  # two sets, so the boxset lookup is a real N+1 rather than 50 identical queries the per-request
  # query cache collapses into one
  let(:alpha_set) { create(:boxset, code: 'ALP', name: 'Alpha Set') }
  let(:beta_set) { create(:boxset, code: 'BET', name: 'Beta Set') }

  # no finish factory exists - MagicCardFinish is joined by hand, same as spec/models/magic_card_spec.rb
  def card_with_finishes(boxset, number, *finish_names)
    create(:magic_card, boxset: boxset, card_number: number).tap do |card|
      finish_names.each do |name|
        MagicCardFinish.create!(magic_card: card, finish: Finish.find_or_create_by!(name: name))
      end
    end
  end

  # no color factory either - MagicCardColorIdent is the association :colors actually resolves to
  def color_ident(card, *color_names)
    color_names.each do |name|
      MagicCardColorIdent.create!(magic_card: card, color: Color.find_or_create_by!(name: name))
    end
  end

  def queries_for(params)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
    end

    get load_boxset_path, params: params, as: :turbo_stream

    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  before do
    card_with_finishes(alpha_set, '1', 'nonfoil', 'foil')
    card_with_finishes(alpha_set, '2', 'etched')
    card_with_finishes(beta_set, '3', 'nonfoil')
    card_with_finishes(beta_set, '4', 'foil', 'etched')
  end

  # the table renders card.boxset.keyrune_code and three finish predicates per row, anonymous or
  # not - without the preload that was 50 finishes queries and 50 boxsets queries per page
  describe 'GET load_boxset in table view' do
    it 'loads finishes once for the whole page' do
      expect(queries_for(code: 'all').grep(/FROM "finishes"/).size).to eq(1)
    end

    it 'does not look up boxsets one row at a time' do
      expect(queries_for(code: 'all').grep(/"boxsets"\."id" = /)).to be_empty
    end

    it 'renders' do
      queries_for(code: 'all')

      expect(response).to have_http_status(:success)
    end
  end

  # _visual_card.html.erb reads neither association, so a visual load shouldn't pay for the preload
  describe 'GET load_boxset in visual view' do
    it 'does not preload finishes' do
      expect(queries_for(code: 'all', view_mode: 'visual').grep(/FROM "finishes"/)).to be_empty
    end
  end

  # this branch skips pagination and hands the whole set to GroupCards, which reads card.colors per
  # card when grouping by color - on an unloaded association empty?/size/first each cost a query.
  # Grouping needs a specific boxset selected, so these pass a real code rather than 'all'
  describe 'GET load_boxset grouped in visual view' do
    before do
      alpha_set.magic_cards.each { |card| color_ident(card, 'White') }
    end

    it 'loads colors once for the whole group instead of per card' do
      queries = queries_for(code: 'ALP', view_mode: 'visual', grouping: 'color')

      expect(queries.grep(/FROM "colors"/).size).to eq(1)
    end

    it 'does not count or check colors one card at a time' do
      queries = queries_for(code: 'ALP', view_mode: 'visual', grouping: 'color')

      expect(queries.grep(/COUNT\(\*\).*"magic_card_color_idents"/)).to be_empty
    end

    it 'renders the grouped view' do
      queries_for(code: 'ALP', view_mode: 'visual', grouping: 'color')

      expect(response).to have_http_status(:success)
    end

    # rarity is a plain column, so grouping by it shouldn't drag colors in
    it 'skips the colors preload when grouping by rarity' do
      queries = queries_for(code: 'ALP', view_mode: 'visual', grouping: 'rarity')

      expect(queries.grep(/FROM "colors"/)).to be_empty
    end
  end

  # the rows come back in a turbo stream with no layout, so the order is read off the row markup
  describe 'GET load_boxset sorted' do
    let(:sorted_set) { create(:boxset, code: 'SRT', name: 'Sorted Set') }

    def rendered_order(params)
      get load_boxset_path, params: params.merge(code: 'SRT'), as: :turbo_stream

      response.body.scan(/expandable-row#toggle"\s+data-card-id="(\d+)"/).flatten.map(&:to_i)
    end

    let!(:cheap) do
      create(:magic_card, boxset: sorted_set, card_number: '1', name: 'Zebra', normal_price: 1, foil_price: 30)
    end
    let!(:pricey) do
      create(:magic_card, boxset: sorted_set, card_number: '2', name: 'Aardvark', normal_price: 20, foil_price: 2)
    end
    let!(:unpriced) do
      create(:magic_card, boxset: sorted_set, card_number: '3', name: 'Mongoose', normal_price: nil, foil_price: nil)
    end

    it 'defaults to card number order' do
      expect(rendered_order({})).to eq([cheap.id, pricey.id, unpriced.id])
    end

    it 'sorts by name' do
      expect(rendered_order(sort: 'name')).to eq([pricey.id, unpriced.id, cheap.id])
    end

    it 'sorts by regular price, unpriced cards last' do
      expect(rendered_order(sort: 'normal_price', direction: 'desc')).to eq([pricey.id, cheap.id, unpriced.id])
    end

    it 'sorts by foil price, unpriced cards last' do
      expect(rendered_order(sort: 'foil_price', direction: 'desc')).to eq([cheap.id, pricey.id, unpriced.id])
    end

    it 'ignores a column it does not sort by' do
      expect(rendered_order(sort: 'id; DROP TABLE magic_cards')).to eq([cheap.id, pricey.id, unpriced.id])
    end
  end
end
