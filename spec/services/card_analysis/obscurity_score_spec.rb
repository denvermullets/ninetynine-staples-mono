require 'rails_helper'

RSpec.describe CardAnalysis::ObscurityScore, type: :service do
  subject(:obscurity) { described_class.new(max_rank: 30_000) }

  describe '#score' do
    it 'scores a format staple near zero' do
      expect(obscurity.score(1)).to be < 0.15
    end

    it 'scores unplayable bulk near zero' do
      expect(obscurity.score(29_000)).to be < 0.15
    end

    # The whole point of the band: a straight rank inversion put rank-25,000 chaff at the top of every
    # bucket, so the middle has to beat both ends rather than just the popular one.
    it 'scores a mid-rank card above both a staple and bulk' do
      middle = obscurity.score(2500)

      expect(middle).to be > obscurity.score(1)
      expect(middle).to be > obscurity.score(29_000)
    end

    it 'peaks in the mid range' do
      expect(obscurity.score(2500)).to be > 0.9
    end

    it 'treats an unranked card as neutral rather than obscure' do
      expect(obscurity.score(nil)).to eq(described_class::NEUTRAL)
      expect(obscurity.score(nil)).to be < obscurity.score(2500)
    end

    it 'never returns a negative score' do
      expect(obscurity.score(30_000)).to be >= 0.0
    end
  end

  # The scale is a constant rather than MagicCard.maximum(:edhrec_rank): reading it from the table would
  # make a card's obscurity move as sets are ingested, and would collapse entirely on a small dataset.
  describe 'the reference scale' do
    it 'defaults to the fixed reference scale' do
      expect(described_class.new.score(2500)).to eq(described_class.new(max_rank: 30_000).score(2500))
    end

    it 'clamps a rank past the reference scale to bulk rather than overflowing' do
      expect(described_class.new.score(90_000)).to eq(0.0)
    end
  end
end
