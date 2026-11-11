require 'rails_helper'

RSpec.describe Commanders::PartnerPairs, type: :service do
  def bits(*letters)
    letters.sum { |letter| Commanders::ColorMask::BITS.fetch(letter) }
  end

  def partner_text
    'Partner (You can have two commanders if both have partner.)'
  end

  def row(name, colors, text: '', card_type: 'Legendary Creature — Human')
    { name: name, text: text, card_type: card_type, mask: bits(*colors) }
  end

  # The pure half: what pairs with what, and which pairs land on the target.
  describe '.pair' do
    subject(:pairs) { described_class.pair(rows, mask) }

    let(:mask) { bits('W', 'U', 'B', 'G') }

    context 'with plain Partner' do
      let(:rows) do
        [
          row('Thrasios', %w[G U], text: partner_text),
          row('Tymna', %w[W B], text: partner_text),
          row('Kraum', %w[U R], text: partner_text),
          row('Bruse', %w[R W], text: partner_text)
        ]
      end

      it 'keeps both halves of a pair whose identities union to the target' do
        expect(pairs).to eq('Thrasios' => ['Tymna'], 'Tymna' => ['Thrasios'])
      end

      it 'drops a card carrying a colour outside the target, even when it has partners' do
        expect(pairs.keys).not_to include('Kraum', 'Bruse')
      end
    end

    context 'when a pair falls short of the target' do
      let(:mask) { bits('W', 'U', 'B', 'G') }
      let(:rows) { [row('Thrasios', %w[G U], text: partner_text), row('Ishai', %w[W U], text: partner_text)] }

      it 'keeps neither - the point is to reach the colours, not fit inside them' do
        expect(pairs).to be_empty
      end
    end

    context 'with no target' do
      let(:mask) { nil }
      let(:rows) do
        [row('Thrasios', %w[G U], text: partner_text), row('Kraum', %w[U R], text: partner_text),
         row('Loner', %w[B])]
      end

      it 'keeps every card that has any legal partner' do
        expect(pairs.keys).to contain_exactly('Thrasios', 'Kraum')
      end
    end

    context 'with Partner with' do
      let(:mask) { bits('U', 'R', 'G') }
      let(:rows) do
        [
          row('Pir', %w[G], text: "Partner with Toothy, Imaginary Friend (When this creature enters...)\nFlying"),
          row('Toothy, Imaginary Friend', %w[U], text: 'Partner with Pir, Imaginative Rascal'),
          row('Rowan', %w[R], text: 'Partner with Will Kenrith'),
          row('Plain', %w[U R], text: partner_text)
        ]
      end

      it 'pairs only with the named card, never with plain Partner' do
        expect(pairs).to be_empty
      end

      it 'pairs with the named card when the union lands' do
        expect(described_class.pair(rows, bits('U', 'G'))).to eq(
          'Pir' => ['Toothy, Imaginary Friend'], 'Toothy, Imaginary Friend' => ['Pir']
        )
      end
    end

    context 'with dash variants and Friends forever' do
      let(:mask) { bits('W', 'B') }
      let(:rows) do
        [
          row('Survivor A', %w[W], text: 'Partner—Survivors (You can have two commanders if both have this ability.)'),
          row('Survivor B', %w[B], text: 'Partner—Survivors'),
          row('Plain', %w[B], text: partner_text),
          row('Old Friend', %w[W], text: 'Friends forever (You can have two commanders if both have friends forever.)'),
          row('New Friend', %w[B], text: 'Partner—Friends forever')
        ]
      end

      it 'pairs within a variant and treats Friends forever as one group across printings' do
        expect(pairs).to eq(
          'Survivor A' => ['Survivor B'], 'Survivor B' => ['Survivor A'],
          'Old Friend' => ['New Friend'], 'New Friend' => ['Old Friend']
        )
      end
    end

    context 'with Backgrounds and Doctors' do
      let(:mask) { bits('U', 'R') }
      let(:rows) do
        [
          row('Wilson', %w[U], text: "Reach\nChoose a Background (You can have a Background as a second commander.)"),
          row('Flaming Fist', %w[R], card_type: 'Legendary Enchantment — Background'),
          row('Rose Tyler', %w[R], text: "Doctor's companion (You can have two commanders if the other is a Doctor.)"),
          row('The Tenth Doctor', %w[U], card_type: 'Legendary Creature — Time Lord Doctor')
        ]
      end

      it 'pairs a Background chooser with a Background and a companion with a Doctor, and nothing across' do
        expect(pairs).to eq(
          'Wilson' => ['Flaming Fist'], 'Flaming Fist' => ['Wilson'],
          'Rose Tyler' => ['The Tenth Doctor'], 'The Tenth Doctor' => ['Rose Tyler']
        )
      end
    end

    context 'with colourless as the target' do
      let(:mask) { Commanders::ColorMask::COLORLESS }
      let(:rows) { [row('Brass A', [], text: partner_text), row('Brass B', [], text: partner_text)] }

      it 'pairs two colourless partners' do
        expect(pairs.keys).to contain_exactly('Brass A', 'Brass B')
      end
    end
  end

  # The query half: the pool is read off real rows, identity and legality included.
  describe '.call' do
    before { Rails.cache.clear }

    let(:commander_legality) { Legality.find_or_create_by!(name: 'commander') }

    def color(letter)
      Color.find_by(name: letter) || create(:color, name: letter)
    end

    def card(name, colors, legal: true, **attributes)
      created = create(:magic_card, { name: name, text: partner_text, can_be_commander: true }.merge(attributes))
      colors.each { |letter| MagicCardColorIdent.create!(magic_card: created, color: color(letter)) }
      MagicCardLegality.create!(magic_card: created, legality: commander_legality, status: 'Legal') if legal
      created
    end

    it 'unions colour identities across the pool' do
      card('Thrasios', %w[G U])
      card('Tymna', %w[W B])

      expect(described_class.call(mask: bits('W', 'U', 'B', 'G'))).to eq(
        'Thrasios' => ['Tymna'], 'Tymna' => ['Thrasios']
      )
    end

    it 'takes in Backgrounds, which are not commanders on their own' do
      card('Wilson', %w[G], text: 'Choose a Background')
      card('Raised by Giants', %w[G], text: 'Commander creatures you own have base power 10.',
                                      card_type: 'Legendary Enchantment — Background', can_be_commander: false)

      expect(described_class.call(mask: bits('G'))).to include('Raised by Giants' => ['Wilson'])
    end

    it 'leaves out cards that are not commander legal' do
      card('Thrasios', %w[G U])
      card('Banned Partner', %w[W B], legal: false)

      expect(described_class.call(mask: nil)).to be_empty
    end
  end
end
