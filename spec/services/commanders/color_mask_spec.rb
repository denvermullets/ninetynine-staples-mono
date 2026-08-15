require 'rails_helper'

RSpec.describe Commanders::ColorMask, type: :service do
  describe 'the bit layout' do
    it 'covers exactly the five colours' do
      expect(described_class::BITS.keys).to eq(%w[W U B R G])
    end

    it 'gives every one of the 32 identities a mask' do
      expect(described_class::MASKS.size).to eq(32)
    end
  end

  describe '.submasks' do
    it 'returns only colourless for a colourless commander' do
      expect(described_class.submasks(0)).to eq([0])
    end

    # The whole point of the trick: a Jund commander can play mono-coloured, two-coloured and
    # colourless cards, so its pool is the sum of all eight of those buckets.
    it 'returns every identity that fits inside a three-colour one' do
      jund = described_class::BITS.values_at('B', 'R', 'G').sum

      expect(described_class.submasks(jund).size).to eq(8)
    end

    it 'returns all 32 for five colours' do
      expect(described_class.submasks(described_class::ALL).size).to eq(32)
    end

    # Every card sits in exactly one bucket, which is what makes summing submasks an exact distinct
    # count rather than an over-count.
    it 'never includes an identity carrying a colour the commander does not have' do
      mono_white = described_class::BITS.fetch('W')

      expect(described_class.submasks(mono_white)).to eq([0, mono_white])
    end
  end

  describe '.letters' do
    it 'spells an identity back in WUBRG order' do
      grixis = described_class::BITS.values_at('U', 'B', 'R').sum

      expect(described_class.letters(grixis)).to eq('UBR')
    end

    it 'calls the empty identity colourless rather than blank' do
      expect(described_class.letters(0)).to eq('C')
    end
  end

  # colors.id is seeded W=1, G=2, U=3, B=4, R=5 - NOT WUBRG order - so a mask keyed on id would
  # silently swap green and blue. This is the test that catches that.
  describe '.for' do
    it 'reads identity off the colour name and not the colour row id' do
      green = create(:color, name: 'G')
      card = create(:magic_card)
      MagicCardColorIdent.create!(magic_card: card, color: green)

      expect(described_class.for(card)).to eq(described_class::BITS.fetch('G'))
    end

    it 'gives a card with no identity rows the colourless mask' do
      expect(described_class.for(create(:magic_card))).to eq(0)
    end
  end
end
