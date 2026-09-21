require 'rails_helper'

RSpec.describe Decklist::Parse, type: :service do
  def parse(text)
    described_class.call(text: text)
  end

  def boards(text)
    parse(text).values.to_h { |entry| [entry[:name], entry[:board]] }
  end

  it 'keys each entry by its normalized name and keeps the name as typed' do
    expect(parse('4 Lightning Bolt')).to eq('lightning bolt' => { name: 'Lightning Bolt', quantity: 4,
                                                                  board: 'mainboard' })
  end

  it 'reads 1x and a bare name as quantities' do
    entries = parse("2x Sol Ring\nArcane Signet")

    expect(entries.values.map { |entry| entry[:quantity] }).to eq([2, 1])
  end

  it 'keeps names in the order they first appear' do
    expect(parse("1 Sol Ring\n1 Arcane Signet\n1 Sol Ring").keys).to eq(['sol ring', 'arcane signet'])
  end

  it 'strips Moxfield and Archidekt export noise' do
    entries = parse("1 Sol Ring (C21) 263 *F*\n1 Cultivate [Ramp]\n1 Arcane Signet (ELD) 331 ^Have,#37d67a^")

    expect(entries.values.map { |entry| entry[:name] }).to eq(['Sol Ring', 'Cultivate', 'Arcane Signet'])
  end

  it 'normalizes case and curly apostrophes' do
    expect(parse('1 URZA’S SAGA').keys).to eq(["urza's saga"])
  end

  it 'normalizes the spacing around a split card’s slashes' do
    expect(parse("1 Fire//Ice\n1 Wear / Tear").keys).to eq(['fire // ice', 'wear // tear'])
  end

  it 'skips blank lines and comments' do
    expect(parse("\n# note\n// ramp\n   \n1 Sol Ring").keys).to eq(['sol ring'])
  end

  it 'skips a line ending in a colon that is not a header' do
    expect(boards("Ramp:\n1 Sol Ring")).to eq('Sol Ring' => 'mainboard')
  end

  it 'does not enforce the card limit' do
    text = Array.new(described_class::MAX_CARDS + 1) { |i| "1 Card #{i}" }.join("\n")

    expect(parse(text).size).to eq(described_class::MAX_CARDS + 1)
  end

  it 'reads nil as an empty list' do
    expect(parse(nil)).to eq({})
  end

  describe 'boards' do
    it 'defaults to the mainboard before any header' do
      expect(boards("1 Sol Ring\nCommander\n1 Atraxa, Praetors' Voice")).to eq(
        'Sol Ring' => 'mainboard', "Atraxa, Praetors' Voice" => 'commander'
      )
    end

    it 'tags entries with the header above them until the next one' do
      text = "Commander\n1 Atraxa, Praetors' Voice\n\nDeck\n1 Sol Ring\n1 Cultivate\nSideboard\n1 Negate"

      expect(boards(text)).to eq("Atraxa, Praetors' Voice" => 'commander', 'Sol Ring' => 'mainboard',
                                 'Cultivate' => 'mainboard', 'Negate' => 'sideboard')
    end

    it 'reads the colon form of a header' do
      expect(boards("COMMANDER:\n1 Atraxa, Praetors' Voice\nSIDEBOARD:\n1 Negate")).to eq(
        "Atraxa, Praetors' Voice" => 'commander', 'Negate' => 'sideboard'
      )
    end

    it 'maps every header to its board' do
      headers = { 'Commander' => 'commander', 'Companion' => 'mainboard', 'Companions' => 'mainboard',
                  'Deck' => 'mainboard', 'Main Board' => 'mainboard', 'Mainboard' => 'mainboard',
                  'Side Board' => 'sideboard', 'Maybeboard' => 'maybeboard', 'Considering' => 'maybeboard',
                  'Token' => 'tokens', 'Tokens' => 'tokens' }

      headers.each do |header, board|
        expect(boards("Sideboard\n1 Negate\n#{header}\n1 Sol Ring")['Sol Ring']).to eq(board), header
      end
    end

    it 'sums a repeated name into one entry on the first board seen' do
      entries = parse("Commander\n1 Sol Ring\nSideboard\n2 sol ring")

      expect(entries).to eq('sol ring' => { name: 'Sol Ring', quantity: 3, board: 'commander' })
    end
  end
end
