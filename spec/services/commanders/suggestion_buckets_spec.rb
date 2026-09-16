require 'rails_helper'

RSpec.describe Commanders::SuggestionBuckets, type: :service do
  # Plain hashes in, plain hashes out - no database involved.
  def entry(**attrs)
    { oracle_id: SecureRandom.uuid, primary_role: 'removal', raw_fit: 1.0, owned: true,
      obscurity: CardAnalysis::ObscurityScore::NEUTRAL, precon: 0.0, cooccurrence: 0.0 }.merge(attrs)
  end

  def buckets(entries, **overrides)
    described_class.call(entries: entries, deck_role_counts: {}, roles: ['removal'],
                         per_bucket: 10, **overrides)
  end

  def names_in_order(result) = result.first[:cards].pluck(:name)

  describe 'bucketing' do
    it 'reports the deck target and how many the deck already has' do
      result = described_class.call(entries: [entry], deck_role_counts: { 'removal' => 4 },
                                    roles: ['removal'], per_bucket: 10)

      expect(result.first).to include(role: 'removal', target: Commanders::DeckTargets.for('removal'), in_deck: 4)
    end

    it 'drops a role with no candidates rather than rendering an empty bucket' do
      expect(buckets([entry(primary_role: 'ramp')])).to be_empty
    end

    it 'caps a bucket at per_bucket' do
      result = described_class.call(entries: Array.new(5) { entry }, deck_role_counts: {},
                                    roles: ['removal'], per_bucket: 2)

      expect(result.first[:cards].size).to eq(2)
    end

    it 'puts owned cards ahead of unowned ones regardless of score' do
      result = buckets([entry(name: 'Unowned', owned: false, raw_fit: 10.0),
                        entry(name: 'Owned', owned: true, raw_fit: 0.1)])

      expect(names_in_order(result)).to eq(%w[Owned Unowned])
    end
  end

  # Normalising per bucket rather than globally is the difference between the panel working and not.
  describe 'fit normalisation' do
    it 'scales fit against the best card in the bucket' do
      result = buckets([entry(name: 'Best', raw_fit: 4.0), entry(name: 'Half', raw_fit: 2.0)])

      expect(result.first[:cards].map { |card| card[:fit] }).to eq([1.0, 0.5])
    end

    it 'survives a bucket where nothing scored' do
      expect { buckets([entry(raw_fit: 0.0)]) }.not_to raise_error
    end
  end

  describe 'the obscurity multiplier' do
    it 'cuts a format staple and boosts a mid-band card' do
      result = buckets([entry(name: 'Staple', obscurity: 0.0), entry(name: 'Mid', obscurity: 1.0)])

      expect(names_in_order(result)).to eq(%w[Mid Staple])
    end
  end

  # Boost-only, unlike obscurity. 83% of candidates appear in zero Commander precons, so a multiplier
  # centred on NEUTRAL would penalise almost the whole pool - see CardAnalysis::PreconScore.
  describe 'the precon multipliers' do
    it 'ranks a card designers reach for above an identical one they do not' do
      result = buckets([entry(name: 'Never Printed', precon: 0.0), entry(name: 'In Precons', precon: 1.0)])

      expect(names_in_order(result)).to eq(['In Precons', 'Never Printed'])
    end

    it 'ranks a card that pairs with the deck above one that does not' do
      result = buckets([entry(name: 'Unrelated', cooccurrence: 0.0), entry(name: 'Pairs', cooccurrence: 1.0)])

      expect(names_in_order(result)).to eq(%w[Pairs Unrelated])
    end

    it 'never scores a card below its own fit on the precon axes' do
      absent = buckets([entry(precon: 0.0, cooccurrence: 0.0)]).first[:cards].first
      present = buckets([entry(precon: 1.0, cooccurrence: 1.0)]).first[:cards].first

      expect(absent[:score]).to eq(absent[:fit])
      expect(present[:score]).to be > present[:fit]
    end

    # The precon axes refine the ordering inside the obscurity band; they do not override it.
    it 'does not let a format staple in every precon outrank a mid-band card in none' do
      result = buckets([entry(name: 'Staple', obscurity: 0.0, precon: 1.0),
                        entry(name: 'Mid', obscurity: 1.0, precon: 0.0)])

      expect(names_in_order(result)).to eq(%w[Mid Staple])
    end

    it 'ignores the precon axes when their weights are zero' do
      result = buckets([entry(name: 'In Precons', precon: 1.0, raw_fit: 1.0),
                        entry(name: 'Never Printed', precon: 0.0, raw_fit: 1.0)],
                       precon_weight: 0.0, cooccurrence_weight: 0.0)

      expect(result.first[:cards].map { |card| card[:score] }.uniq.size).to eq(1)
    end
  end
end
