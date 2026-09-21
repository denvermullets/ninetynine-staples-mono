require 'rails_helper'

# POST only: the page shell renders a layout CI cannot build, and the turbo stream renders none. What
# a side holds and how two are diffed is DeckComparison::LoadSide's and Compare's business and covered
# there; this is the wiring - logged in only, params in, stream out, own decks only, throttled.
RSpec.describe 'DeckComparisons', type: :request do
  let(:user) { create(:user, username: 'comparer') }

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'password123' }
  end

  def card(name)
    create(:magic_card, name: name, scryfall_oracle_id: SecureRandom.uuid)
  end

  def paste(a_text, b_text, **extra)
    post deck_compare_path, params: { a_source: 'paste', a_text: a_text, b_source: 'paste', b_text: b_text, **extra }
  end

  # the ERB formatter decides where a sentence wraps, so bodies are compared with whitespace squashed
  def body
    response.body.squish
  end

  def expect_counts(shared:, only_a:, only_b:, name_a: 'A')
    expect(body).to include("Shared (#{shared})", "Only in #{name_a} (#{only_a})", "Only in B (#{only_b})")
  end

  # the opening tag of one tab's pane, which carries `hidden` unless it is the active tab
  def pane(tab)
    body[/<div data-deck-compare-target="pane" data-tab="#{tab}"[^>]*>/]
  end

  it 'sends a logged-out visitor to the login page' do
    card('Alpha')

    paste('1 Alpha', '1 Alpha')

    expect(response).to redirect_to(login_path)
  end

  it 'compares two pasted lists' do
    %w[Alpha Bravo Charlie Delta].each { |name| card(name) }
    sign_in(user)

    paste("1 Alpha\n1 Bravo\n1 Charlie", "1 Alpha\n1 Delta")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    expect(body).to include('<turbo-stream action="replace" target="deck_compare_results">',
                            'id="deck_compare_results"')
    expect_counts(shared: 1, only_a: 2, only_b: 1)
  end

  it 'reports names it could not match' do
    sign_in(user)
    card('Alpha')

    paste("1 Alpha\n1 Sol Rnig", '1 Alpha')

    expect(body).to include('Deck A: No card found for 1 Sol Rnig')
  end

  it 'shows both counts for a shared card the decks hold in different numbers' do
    sign_in(user)
    card('Forest')

    paste('12 Forest', '9 Forest')

    expect_counts(shared: 1, only_a: 0, only_b: 0)
    expect(body).to include('12 / 9')
  end

  it 'renders the asked-for tab open and the others hidden' do
    %w[Alpha Bravo].each { |name| card(name) }
    sign_in(user)

    paste('1 Alpha', '1 Bravo', tab: 'only_b')

    expect(pane('only_b')).not_to include('hidden')
    expect(pane('shared')).to include('hidden')
    expect(pane('only_a')).to include('hidden')
  end

  it 'still compares when one side is empty' do
    sign_in(user)
    card('Alpha')

    paste('1 Alpha', '')

    expect_counts(shared: 0, only_a: 1, only_b: 0)
    expect(body).to include('Deck B is empty')
  end

  it 'renders the card view' do
    sign_in(user)
    card('Alpha')

    paste('1 Alpha', '1 Alpha', view_mode: 'card')

    expect(body).to include('data-view-mode="card"', 'data-controller="card-stack"')
  end

  it 'falls back to the defaults for view options it does not know' do
    sign_in(user)
    card('Alpha')

    paste('1 Alpha', '1 Alpha', view_mode: 'grid', tab: 'everything', grouping: 'zone', sort_by: 'chaos')

    expect(response).to have_http_status(:ok)
    expect(body).to include('data-tab="shared"', 'data-view-mode="list"')
  end

  it 'asks for decks when both sides are empty' do
    sign_in(user)
    post deck_compare_path

    expect(response).to have_http_status(:ok)
    expect(body).to include('Paste a decklist or pick a deck')
    expect(body).not_to include('Shared')
  end

  it 'compares one of the viewer\'s own decks with a pasted list' do
    deck = create(:collection, user: user, name: 'Atraxa', collection_type: 'commander_deck')
    [card('Alpha'), card('Bravo')].each do |magic_card|
      create(:collection_magic_card, collection: deck, magic_card: magic_card, quantity: 1)
    end
    card('Charlie')
    sign_in(user)

    post deck_compare_path, params: { a_source: 'deck', a_deck_id: deck.id, b_source: 'paste',
                                      b_text: "1 Alpha\n1 Charlie" }

    expect(response).to have_http_status(:ok)
    expect_counts(shared: 1, only_a: 1, only_b: 1, name_a: 'Atraxa')
  end

  it 'refuses another user\'s deck without showing what is in it' do
    deck = create(:collection, user: create(:user, username: 'stranger'), collection_type: 'commander_deck')
    create(:collection_magic_card, collection: deck, magic_card: card('Secret Tech'), quantity: 1)
    card('Alpha')
    sign_in(user)

    post deck_compare_path, params: { a_source: 'deck', a_deck_id: deck.id, b_source: 'paste', b_text: '1 Alpha' }

    expect(response).to have_http_status(:ok)
    expect(body).to include('Deck A: Pick one of your decks.')
    expect(body).not_to include('Secret Tech', 'Shared')
  end

  it 'refuses a pasted list over the card cap' do
    sign_in(user)
    too_many = Array.new(DeckComparison::LoadSide::FromPaste::MAX_CARDS + 1) { |index| "1 Card #{index}" }

    paste(too_many.join("\n"), '1 Alpha')

    expect(response).to have_http_status(:ok)
    expect(body).to include('Deck A: Paste at most 150 cards per deck.')
    expect(body).not_to include('Shared')
  end

  it 'throttles the 31st comparison in a minute' do
    sign_in(user)
    30.times { post deck_compare_path }
    expect(response).to have_http_status(:ok)

    post deck_compare_path

    expect(response).to have_http_status(:too_many_requests)
  end
end
