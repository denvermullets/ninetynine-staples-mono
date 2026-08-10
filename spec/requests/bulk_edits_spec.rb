require 'rails_helper'

RSpec.describe 'BulkEdits', type: :request do
  let(:user) { create(:user) }
  let(:deck_box) { create(:collection, user: user, name: 'Deck Box') }
  let(:magic_card) { create(:magic_card) }

  before { post login_path, params: { email: user.email, password: 'password123' } }

  def save_rows(rows)
    post bulk_edit_save_path,
         params: { rows: rows }.to_json,
         headers: { 'CONTENT_TYPE' => 'application/json', 'Accept' => 'text/vnd.turbo-stream.html' }
  end

  def base_row(overrides = {})
    {
      magic_card_id: magic_card.id, card_uuid: nil,
      from_collection_id: CollectionRecord::BulkApply::BRAND_NEW, to_collection_id: deck_box.id,
      quantity: 0, foil_quantity: 0, proxy_quantity: 0, proxy_foil_quantity: 0
    }.merge(overrides)
  end

  # two sets, so the boxset lookup is a real N+1 rather than identical queries the per-request
  # query cache collapses into one. No finish factory exists - MagicCardFinish is joined by hand,
  # same as spec/requests/boxsets_spec.rb
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

    get bulk_edit_load_table_path, params: params, as: :turbo_stream

    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # the table renders card.boxset.keyrune_code and both price predicates per row, and load_cards
  # doesn't paginate - without the preload every row cost its own finishes query
  describe 'GET /bulk-edit/table' do
    let(:alpha_set) { create(:boxset, code: 'ALP', name: 'Alpha Set') }
    let(:beta_set) { create(:boxset, code: 'BET', name: 'Beta Set') }

    before do
      card_with_finishes(alpha_set, '1', 'nonfoil', 'foil')
      card_with_finishes(alpha_set, '2', 'etched')
      card_with_finishes(beta_set, '3', 'nonfoil')
      card_with_finishes(beta_set, '4', 'foil', 'etched')
    end

    it 'loads finishes once for the whole table' do
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

  describe 'POST /bulk-edit/save' do
    context 'when the batch applies cleanly' do
      it 'appends a success toast and flags success for the client' do
        save_rows([base_row(quantity: 3)])

        expect(response).to have_http_status(:ok)
        expect(response.headers['X-Bulk-Edit-Success']).to eq('true')
        expect(response.body).to include('action="append"', 'target="toasts"')
        expect(response.body).to include('data-controller="toast"', 'bg-accent-50')
        expect(response.body).to include('Saved 1 change.')
      end
    end

    context 'when nothing was submitted' do
      it 'appends an error toast' do
        save_rows([])

        expect(response.body).to include('bg-accent-100')
        expect(response.body).to include('Nothing to save')
      end
    end

    context 'when a row fails validation' do
      it 'appends a rollback toast naming the card and flags failure' do
        save_rows([base_row(from_collection_id: deck_box.id, quantity: 1)])

        expect(response.headers['X-Bulk-Edit-Success']).to eq('false')
        expect(response.body).to include('bg-accent-100')
        expect(response.body).to include('Save rolled back — 1 error.')
        expect(response.body).to include("#{magic_card.name}: FROM and TO must differ")
      end
    end
  end
end
