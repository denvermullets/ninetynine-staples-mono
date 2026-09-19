require 'rails_helper'

RSpec.describe 'WantListItems', type: :request do
  let(:user) { create(:user) }
  let(:oracle_id) { SecureRandom.uuid }
  let(:magic_card) { create(:magic_card, scryfall_oracle_id: oracle_id) }
  let(:other_printing) { create(:magic_card, scryfall_oracle_id: oracle_id, boxset: create(:boxset)) }

  def log_in
    post login_path, params: { email: user.email, password: 'password123' }
  end

  describe 'POST /want_list_items' do
    it 'sends logged-out viewers to the login page without creating anything' do
      expect do
        post want_list_items_path, params: { magic_card_id: magic_card.id }, as: :turbo_stream
      end.not_to change(WantListItem, :count)

      expect(response).to redirect_to(login_path)
    end

    context 'when logged in' do
      before { log_in }

      it 'adds the card and refreshes its details frame' do
        expect do
          post want_list_items_path, params: { magic_card_id: magic_card.id }, as: :turbo_stream
        end.to change(user.want_list_items, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("card_details_#{magic_card.id}")
        expect(response.body).to include('Remove from want list')
      end

      it 'reuses the any-printing row when another printing is added' do
        create(:want_list_item, user: user, magic_card: other_printing)

        expect do
          post want_list_items_path, params: { magic_card_id: magic_card.id }, as: :turbo_stream
        end.not_to change(WantListItem, :count)

        expect(response.body).to include("card_details_#{magic_card.id}")
        expect(response.body).to include('Covered by your want for any printing')
      end

      it 'refreshes the open row rather than the printing that was wanted' do
        post want_list_items_path,
             params: { magic_card_id: other_printing.id, refresh_card_id: magic_card.id, show_other_printings: true },
             as: :turbo_stream

        expect(response.body).to include("card_details_#{magic_card.id}")
        expect(response.body).not_to include("card_details_#{other_printing.id}")
      end

      it 'answers with an error toast for an unknown card' do
        post want_list_items_path, params: { magic_card_id: 0 }, as: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Card not found.')
        expect(response.body).not_to include('card_details_')
      end
    end
  end

  describe 'PATCH /want_list_items/:id' do
    let!(:item) { create(:want_list_item, user: user, magic_card: magic_card) }

    before { log_in }

    it 'updates the row and refreshes the details frame' do
      patch want_list_item_path(item),
            params: { quantity: 3, foil_preference: 'foil', any_printing: '0', notes: ' borderless please ',
                      refresh_card_id: magic_card.id },
            as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("card_details_#{magic_card.id}")
      expect(item.reload).to have_attributes(quantity: 3, foil_preference: 'foil', any_printing: false,
                                             notes: 'borderless please')
    end

    it 'refreshes the printing the user has open when the row names another one' do
      patch want_list_item_path(item), params: { quantity: 2, refresh_card_id: other_printing.id },
                                       as: :turbo_stream

      expect(response.body).to include("card_details_#{other_printing.id}")
      expect(response.body).not_to include("card_details_#{magic_card.id}")
    end

    it "does not touch another user's row" do
      theirs = create(:want_list_item, magic_card: magic_card)

      patch want_list_item_path(theirs), params: { quantity: 9 }, as: :turbo_stream

      expect(response.body).to include('Card not found on your want list.')
      expect(theirs.reload.quantity).to eq(1)
    end
  end

  describe 'DELETE /want_list_items/:id' do
    let!(:item) { create(:want_list_item, user: user, magic_card: magic_card) }

    before { log_in }

    it 'removes the row and refreshes the details frame' do
      expect do
        delete want_list_item_path(item), params: { refresh_card_id: magic_card.id }, as: :turbo_stream
      end.to change(user.want_list_items, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("card_details_#{magic_card.id}")
      expect(response.body).to include('Add to want list')
    end

    it "does not remove another user's row" do
      theirs = create(:want_list_item, magic_card: magic_card)

      expect do
        delete want_list_item_path(theirs), as: :turbo_stream
      end.not_to change(WantListItem, :count)
    end
  end

  # the want list page's forms: answered with a redirect back to the page, never a rendered frame
  describe 'from the want list page' do
    let!(:item) { create(:want_list_item, user: user, magic_card: magic_card) }

    before { log_in }

    it 'updates the row and goes back to the view it came from' do
      patch want_list_item_path(item),
            params: { quantity: 4, return_to: 'want_list', filter: 'owned', sort: 'price', page: '2' }

      expect(item.reload.quantity).to eq(4)
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(collection_wants_path(user.username, filter: 'owned', sort: 'price', page: '2'))
    end

    it 'removes the row and goes back to the list' do
      expect do
        delete want_list_item_path(item), params: { return_to: 'want_list' }
      end.to change(user.want_list_items, :count).by(-1)

      expect(response).to redirect_to(collection_wants_path(user.username))
    end

    it 'goes back with the error when the row is gone' do
      item.destroy!

      delete want_list_item_path(item), params: { return_to: 'want_list' }

      expect(response).to redirect_to(collection_wants_path(user.username))
      expect(flash[:alert]).to eq('Card not found on your want list.')
    end
  end
end
