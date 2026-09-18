require 'rails_helper'

# The builder, inbox and trade pages themselves are not requested here - they render a layout CI
# cannot build. What is left is everything that answers without rendering one: the guards on the way
# in, and the writes, which either redirect or come back as a turbo-stream toast.
RSpec.describe 'Trades', type: :request do
  let(:proposer) { create(:user, username: 'proposer', trades_public: true) }
  let(:recipient) { create(:user, username: 'recipient', trades_public: true) }
  let(:lotus) { create(:magic_card, name: 'Black Lotus', normal_price: 10, foil_price: 30) }

  def binder_row(user, trade_quantity: 4)
    collection = create(:collection, user: user, is_public: true)
    create(:collection_magic_card, collection: collection, magic_card: lotus, quantity: 4,
                                   trade_quantity: trade_quantity)
  end

  def item(row, side, quantity: 1)
    { collection_magic_card_id: row.id, side: side, quantity: quantity, foil_quantity: 0 }
  end

  # the builder posts its draft as JSON and asks for a turbo-stream back, the way the fetch does
  def turbo_stream_accept
    { 'Accept' => 'text/vnd.turbo-stream.html' }
  end

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'password123' }
  end

  describe 'GET /trades/new' do
    it 'sends a logged-out visitor to the login page' do
      get new_trade_path(with: recipient.username)

      expect(response).to redirect_to(login_path)
    end

    it 'bounces a username it does not have' do
      sign_in(proposer)

      get new_trade_path(with: 'nobody')

      expect(response).to redirect_to(root_path)
    end

    it 'bounces a trade with yourself' do
      sign_in(proposer)

      get new_trade_path(with: proposer.username)

      expect(response).to redirect_to(root_path)
    end

    it 'bounces a counterparty whose trade list is private' do
      recipient.update!(trades_public: false)
      sign_in(proposer)

      get new_trade_path(with: recipient.username)

      expect(response).to redirect_to(root_path)
    end
  end

  describe 'POST /trades' do
    before { sign_in(proposer) }

    it 'creates the trade and sends the proposer to it' do
      mine = binder_row(proposer)
      theirs = binder_row(recipient)

      post trades_path, params: { with: recipient.username, message: 'fair?',
                                  items: { '0' => item(mine, 'proposer', quantity: 2),
                                           '1' => item(theirs, 'recipient') } }

      trade = Trade.last
      expect(response).to redirect_to(trade_path(trade))
      expect(trade).to have_attributes(proposer_id: proposer.id, recipient_id: recipient.id,
                                       message: 'fair?')
      expect(trade.items_for('proposer').sum(&:quantity)).to eq(2)
    end

    it 'refuses a counterparty whose trade list is private' do
      recipient.update!(trades_public: false)

      post trades_path, params: { with: recipient.username,
                                  items: { '0' => item(binder_row(proposer), 'proposer') } },
                        as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('not accepting trade offers')
      expect(Trade.count).to be_zero
    end

    it 'refuses more copies than the owner has on offer' do
      mine = binder_row(proposer, trade_quantity: 1)

      post trades_path, params: { with: recipient.username,
                                  items: { '0' => item(mine, 'proposer', quantity: 3) } },
                        as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('available to trade')
      expect(Trade.count).to be_zero
    end

    it 'refuses a trade with yourself' do
      post trades_path, params: { with: proposer.username,
                                  items: { '0' => item(binder_row(proposer), 'proposer') } },
                        as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('two different users')
      expect(Trade.count).to be_zero
    end
  end

  describe 'POST /trades/preview' do
    before { sign_in(proposer) }

    it 'totals the draft without writing anything' do
      theirs = binder_row(recipient)

      post preview_trades_path, params: { with: recipient.username,
                                          items: [item(theirs, 'recipient', quantity: 2)] },
                                as: :json, headers: turbo_stream_accept

      expect(response.body).to include('trade_totals')
      expect(response.body).to include('$20.00')
      expect(Trade.count).to be_zero
    end

    it 'refuses a username it does not have' do
      post preview_trades_path, params: { with: 'nobody', items: [] }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /trades' do
    it 'sends a logged-out visitor to the login page' do
      get trades_path

      expect(response).to redirect_to(login_path)
    end
  end

  describe 'GET /trades/:id' do
    let(:trade) { create(:trade, proposer: proposer, recipient: recipient) }

    it 'sends a logged-out visitor to the login page' do
      get trade_path(trade)

      expect(response).to redirect_to(login_path)
    end

    it 'is a 404 for anyone who is not a party to the trade' do
      sign_in(create(:user, username: 'outsider'))

      get trade_path(trade)

      expect(response).to have_http_status(:not_found)
    end

    it 'is a 404 for a trade that does not exist' do
      sign_in(proposer)

      get trade_path(id: 0)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /trades/:id/transition' do
    let(:trade) { create(:trade, proposer: proposer, recipient: recipient) }

    it 'sends a logged-out visitor to the login page' do
      patch transition_trade_path(trade), params: { event: 'accept' }

      expect(response).to redirect_to(login_path)
      expect(trade.reload).to be_proposed
    end

    it 'is a 404 for anyone who is not a party to the trade' do
      sign_in(create(:user, username: 'outsider'))

      patch transition_trade_path(trade), params: { event: 'cancel' }

      expect(response).to have_http_status(:not_found)
      expect(trade.reload).to be_proposed
    end

    it 'lets the recipient answer and sends them back to the trade' do
      sign_in(recipient)

      patch transition_trade_path(trade), params: { event: 'accept' }

      expect(response).to redirect_to(trade_path(trade))
      expect(trade.reload).to be_accepted
    end

    it 'refuses a step the state machine does not allow the caller' do
      sign_in(proposer)

      patch transition_trade_path(trade), params: { event: 'accept' }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Only the recipient')
      expect(trade.reload).to be_proposed
    end
  end
end
