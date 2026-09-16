require 'rails_helper'

RSpec.describe CardAnalysis::PreconScore, type: :service do
  subject(:score) { described_class.new }

  describe '#inclusion' do
    it 'scores a card that appears in no precon at zero' do
      expect(score.inclusion(0.0)).to eq(0.0)
      expect(score.inclusion(nil)).to eq(0.0)
    end

    it 'scores a higher inclusion rate above a lower one' do
      expect(score.inclusion(0.30)).to be > score.inclusion(0.05)
      expect(score.inclusion(0.05)).to be > score.inclusion(0.01)
    end

    it 'crosses the halfway mark at HALF' do
      expect(score.inclusion(described_class::HALF)).to eq(0.5)
    end

    # Saturating rather than linear: the interesting distinction is between zero, a little and a lot.
    # Measured against the real corpus, the body of the distribution (p10 to p90 of the removal role)
    # lands between 0.14 and 0.48, so the spread sits where the candidates actually are.
    it 'saturates below 1.0 rather than running away at the top' do
      expect(score.inclusion(0.90)).to be < 1.0
      expect(score.inclusion(0.30)).to be > 0.8
    end

    it 'never exceeds 1.0' do
      expect(score.inclusion(1_000.0)).to be <= 1.0
    end
  end

  describe '#cooccurrence' do
    it 'ignores a lift measured on too few precons' do
      expect(score.cooccurrence(lift: 20.0, support: described_class::MIN_SUPPORT - 1)).to eq(0.0)
    end

    it 'scores a card with no pair data at zero' do
      expect(score.cooccurrence(lift: nil, support: nil)).to eq(0.0)
    end

    it 'scores a card that appears at its base rate at zero' do
      expect(score.cooccurrence(lift: 1.0, support: 10)).to eq(0.0)
    end

    it 'scores a card below its base rate at zero rather than negative' do
      expect(score.cooccurrence(lift: 0.2, support: 10)).to eq(0.0)
    end

    it 'scores a stronger pairing above a weaker one' do
      strong = score.cooccurrence(lift: 2.5, support: 10)
      weak = score.cooccurrence(lift: 1.5, support: 10)

      expect(strong).to be > weak
      expect(weak).to be > 0.0
    end

    # A tribal deck can drive lift past 20x. Letting that run linearly would let one anchor match
    # dominate a whole bucket, so it clamps at the reference.
    it 'clamps an extreme lift to 1.0' do
      expect(score.cooccurrence(lift: 20.0, support: 10)).to eq(1.0)
      expect(score.cooccurrence(lift: described_class::LIFT_REFERENCE, support: 10)).to eq(1.0)
    end
  end
end
