require 'rails_helper'

RSpec.describe Collections::ViewMode, type: :service do
  def view(params = {})
    described_class.new(params: params)
  end

  describe '#call' do
    it 'defaults to the table view with no grouping' do
      expect(view.call).to eq(view_mode: 'table', grouping: 'none', grouping_allowed: false)
    end

    it 'reads the view mode and grouping from params' do
      result = view(view_mode: 'visual', grouping: 'rarity', code: 'TST').call

      expect(result[:view_mode]).to eq('visual')
      expect(result[:grouping]).to eq('rarity')
      expect(result[:grouping_allowed]).to be(true)
    end

    # it only decides whether the grouping selector is offered - the caller paginates either way,
    # so an unrecognized code can no longer load the whole collection
    it 'allows grouping only when a boxset code is present' do
      expect(view(code: 'TST').call[:grouping_allowed]).to be(true)
      expect(view.call[:grouping_allowed]).to be(false)
    end

    it 'does not query the database' do
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
      end

      view(view_mode: 'visual', grouping: 'rarity', code: 'TST').call

      expect(queries).to be_empty
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end

  describe '#visual?' do
    it 'is true in visual mode' do
      expect(view(view_mode: 'visual')).to be_visual
    end

    it 'is false in table mode and by default' do
      expect(view(view_mode: 'table')).not_to be_visual
      expect(view).not_to be_visual
    end
  end
end
