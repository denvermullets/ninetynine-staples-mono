require 'rails_helper'

# Answered with turbo streams of partials, so these render no layout. What gets resolved and added is
# WantList::BulkImport's business and covered there.
RSpec.describe 'WantImports', type: :request do
  let(:user) { create(:user, username: 'wanter') }

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'password123' }
  end

  it 'sends a logged-out visitor to the login page' do
    post want_imports_path, params: { decklist: '1 Sol Ring' }

    expect(response).to redirect_to(login_path)
  end

  it 'adds the pasted cards to the signed-in user' do
    create(:magic_card, name: 'Sol Ring', scryfall_oracle_id: SecureRandom.uuid)
    sign_in(user)

    post want_imports_path, params: { decklist: "1 Sol Ring\n1 Not A Card" }, as: :turbo_stream

    expect(response.media_type).to eq(Mime[:turbo_stream])
    expect(user.want_list_items.count).to eq(1)
  end

  it 'answers a paste over the limit' do
    sign_in(user)
    text = Array.new(WantList::BulkImport::MAX_CARDS + 1) { |i| "1 Card #{i}" }.join("\n")

    post want_imports_path, params: { decklist: text }, as: :turbo_stream

    expect(response.media_type).to eq(Mime[:turbo_stream])
  end
end
