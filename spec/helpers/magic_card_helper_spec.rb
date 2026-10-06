require 'rails_helper'

RSpec.describe MagicCardHelper, type: :helper do
  describe '#reserved_tint_class' do
    it 'tints a card on the Reserved List' do
      expect(helper.reserved_tint_class(build(:magic_card, is_reserved: true))).to include('from-ink-gold-accent')
    end

    it 'leaves every other card alone' do
      expect(helper.reserved_tint_class(build(:magic_card, is_reserved: false))).to be_nil
    end
  end
end
