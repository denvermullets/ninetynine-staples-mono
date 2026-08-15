require 'rails_helper'

# Pure Ruby over a hand-built profile - the query that produces one is CollectionStats::BuildableProfile
# and has its own spec. What matters here is the submask arithmetic and what completeness counts.
RSpec.describe Commanders::Buildability, type: :service do
  subject(:result) { described_class.call(profile: profile, mask: mask) }

  let(:mask) { bits('B') }

  def bits(*letters)
    letters.sum { |letter| Commanders::ColorMask::BITS.fetch(letter) }
  end

  def bucket(cards:, roles: {}, effects: {})
    { distinct_cards: cards, role_counts: roles, effect_counts: effects }
  end

  # Empty everywhere except where an example fills it in, so a bucket that should not be counted
  # showing up is visible as a change in the number rather than as a missing key.
  let(:profile) { Commanders::ColorMask::MASKS.index_with { bucket(cards: 0) } }

  describe 'the submask sum' do
    it 'counts colourless cards toward a coloured commander' do
      profile[0] = bucket(cards: 12)

      expect(result[:owned_pool]).to eq(12)
    end

    it 'counts its own identity and every identity inside it' do
      profile[0] = bucket(cards: 5)
      profile[bits('B')] = bucket(cards: 7)
      profile[bits('B', 'R')] = bucket(cards: 100)

      expect(described_class.call(profile: profile, mask: bits('B', 'R'))[:owned_pool]).to eq(112)
    end

    # The gate that makes the page mean anything: a card outside the identity is not a worse
    # suggestion, it is an illegal one.
    it 'leaves out an identity carrying a colour the commander does not have' do
      profile[bits('B')] = bucket(cards: 7)
      profile[bits('G')] = bucket(cards: 500)

      expect(result[:owned_pool]).to eq(7)
    end

    it 'adds role counts across the submasks rather than taking the deepest one' do
      profile[0] = bucket(cards: 3, roles: { 'ramp' => 3 })
      profile[bits('B')] = bucket(cards: 4, roles: { 'ramp' => 4 })

      expect(result[:role_coverage]['ramp'][:owned]).to eq(7)
    end
  end

  describe 'role coverage' do
    it 'reports every target role, including the ones with nothing owned' do
      expect(result[:role_coverage].keys).to eq(Commanders::DeckTargets::ROLES)
    end

    it 'reports the shortfall against the deck target' do
      profile[bits('B')] = bucket(cards: 4, roles: { 'ramp' => 4 })

      expect(result[:role_coverage]['ramp']).to include(owned: 4, target: 10, short: 6)
    end

    it 'does not report a negative shortfall once the target is cleared' do
      profile[bits('B')] = bucket(cards: 40, roles: { 'ramp' => 40 })

      expect(result[:role_coverage]['ramp']).to include(short: 0, share: 100.0)
    end
  end

  describe 'completeness' do
    it 'is zero for a collection with nothing in the commander identity' do
      expect(result[:completeness]).to eq(0.0)
    end

    it 'is one when every spell role clears its target' do
      roles = Commanders::Buildability::SPELL_ROLES.index_with { |role| Commanders::DeckTargets.for(role) }
      profile[bits('B')] = bucket(cards: 100, roles: roles)

      expect(result[:completeness]).to eq(1.0)
    end

    # You cannot fill a removal slot with a Sol Ring, so a surplus in one role is not credit against
    # another.
    it 'does not let a surplus in one role bank against a role with nothing in it' do
      profile[bits('B')] = bucket(cards: 200, roles: { 'ramp' => 200 })
      ramp_share = Commanders::DeckTargets.for('ramp').fdiv(described_class::SPELL_SLOTS)

      expect(result[:completeness]).to eq(ramp_share.round(4))
    end

    # Manabase is 36 of the 74 slots in DeckTargets and basics fill any gap in it for free. Counting
    # it would report every collection as roughly half complete before a single spell was counted.
    it 'leaves manabase out of the denominator' do
      profile[bits('B')] = bucket(cards: 100, roles: { 'manabase' => 36 })

      expect(result[:completeness]).to eq(0.0)
    end

    it 'still reports manabase on its own' do
      profile[bits('B')] = bucket(cards: 100, roles: { 'manabase' => 36 })

      expect(result[:manabase]).to include(owned: 36, short: 0)
    end
  end

  describe 'the bottleneck' do
    it 'names the role furthest from its target' do
      profile[bits('B')] = bucket(cards: 50, roles: { 'ramp' => 10, 'card_draw' => 10,
                                                      'removal' => 8, 'protection' => 4,
                                                      'tutor' => 3, 'recursion' => 0 })

      expect(result[:bottleneck]).to eq('recursion')
    end

    it 'is nil once nothing is short' do
      roles = Commanders::Buildability::SPELL_ROLES.index_with { |role| Commanders::DeckTargets.for(role) }
      profile[bits('B')] = bucket(cards: 100, roles: roles)

      expect(result[:bottleneck]).to be_nil
    end
  end
end
