require 'rails_helper'

RSpec.describe 'Collections', type: :request do
  # a plain username - Faker's can contain a dot, which the :username route segment
  # would read as a format separator
  let(:user) { create(:user, username: 'tester') }
  let(:collection) { create(:collection, user: user) }
  let(:boxset) { create(:boxset, keyrune_code: 'TST') }
  let!(:cheap_card) do
    create(:magic_card, name: 'Dark Ritual', card_number: '2', normal_price: 5.0, rarity: 'rare', boxset: boxset)
  end
  let!(:pricey_card) do
    create(:magic_card, name: 'Lightning Bolt', card_number: '10', normal_price: 10.0, rarity: 'rare', boxset: boxset)
  end

  before do
    create(:collection_magic_card, collection: collection, magic_card: cheap_card, quantity: 1)
    create(:collection_magic_card, collection: collection, magic_card: pricey_card, quantity: 1)
    post login_path, params: { email: user.email, password: 'password123' }
  end

  describe 'GET /collections/:username' do
    it 'orders by owned price with no sort param' do
      get collection_show_path(username: user.username)

      expect(response.body.index('Lightning Bolt')).to be < response.body.index('Dark Ritual')
    end

    it 'orders by the requested column' do
      get collection_show_path(username: user.username), params: { sort: 'name', direction: 'asc' }

      expect(response.body.index('Dark Ritual')).to be < response.body.index('Lightning Bolt')
    end

    it 'sorts card numbers numerically' do
      get collection_show_path(username: user.username), params: { sort: 'card_number', direction: 'asc' }

      expect(response.body.index('Dark Ritual')).to be < response.body.index('Lightning Bolt')
    end

    it 'renders sortable headings that flip direction and keep the current filters' do
      get collection_show_path(username: user.username),
          params: { sort: 'name', direction: 'asc', search: 'Dark', hide_proxies: 'false' }

      headings = Nokogiri::HTML(response.body).css('thead a')
      name_link = headings.map { |link| link['href'] }.find { |href| href.include?('sort=name') }

      # the active column flips to desc, and the search/filter state rides along
      expect(name_link).to include('direction=desc', 'search=Dark', 'hide_proxies=false')
      expect(headings.map { |link| link.text.squish }).to include('Name ▲')
    end

    it 'falls back to the owned price ordering for an unknown sort column' do
      get collection_show_path(username: user.username), params: { sort: 'drop table' }

      expect(response.body.index('Lightning Bolt')).to be < response.body.index('Dark Ritual')
    end
  end
end
