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
