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
end
