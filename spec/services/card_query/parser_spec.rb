require 'rails_helper'

RSpec.describe CardQuery::Parser, type: :service do
  def parse(query) = described_class.call(query: query)

  describe 'plain name searches' do
    it 'is not advanced and keeps the whole string as free text' do
      result = parse('lightning bolt')

      expect(result).not_to be_advanced
      expect(result.terms).to be_empty
      expect(result.free_text).to eq('lightning bolt')
    end

    it 'handles a blank query' do
      result = parse('')

      expect(result).not_to be_advanced
      expect(result.free_text).to eq('')
    end

    it 'handles a nil query' do
      expect { parse(nil) }.not_to raise_error
      expect(parse(nil).free_text).to eq('')
    end
  end

  describe 'term extraction' do
    it 'pulls out multiple terms' do
      result = parse('c:b t:creature r:uncommon')

      expect(result).to be_advanced
      expect(result.terms.map(&:key)).to eq(%w[c t r])
      expect(result.terms.map(&:value)).to eq(%w[b creature uncommon])
      expect(result.free_text).to eq('')
    end

    it 'keeps bare words as free text alongside terms' do
      result = parse('bolt t:instant')

      expect(result.free_text).to eq('bolt')
      expect(result.terms.map(&:key)).to eq(['t'])
    end

    it 'is case insensitive on keys' do
      expect(parse('T:Creature').terms.first.key).to eq('t')
    end
  end

  describe 'operators' do
    it 'parses every comparison operator' do
      result = parse('mv>1 mv>=2 mv<3 mv<=4 mv=5 mv!=6')

      expect(result.terms.map(&:op)).to eq(['>', '>=', '<', '<=', '=', '!='])
    end

    it 'maps `:` to the field default so numerics compare by equality' do
      expect(parse('mv:3').terms.first.op).to eq('=')
    end

    it 'maps `:` to "contains" for colors and "subset" for identity' do
      expect(parse('c:b').terms.first.op).to eq('>=')
      expect(parse('id:b').terms.first.op).to eq('<=')
    end

    it 'leaves `:` alone for substring fields' do
      expect(parse('t:creature').terms.first.op).to eq(':')
    end
  end

  describe 'negation' do
    it 'marks a leading dash as negated' do
      result = parse('t:goblin -t:legendary')

      expect(result.terms.map(&:negated?)).to eq([false, true])
    end
  end

  describe 'quoted phrases' do
    it 'keeps a quoted value together and strips the quotes' do
      result = parse('o:"draw a card" c:u')

      expect(result.terms.first.value).to eq('draw a card')
      expect(result.terms.last.key).to eq('c')
    end

    it 'unescapes an escaped quote' do
      expect(parse('o:"say \\"hi\\""').terms.first.value).to eq('say "hi"')
    end
  end

  describe 'unknown keys' do
    it 'falls back to free text rather than dropping the token' do
      result = parse('banana:split')

      expect(result).not_to be_advanced
      expect(result.free_text).to eq('banana:split')
      expect(result.ignored).to be_empty
    end

    # names like "Ach! Hans, Run!" are fine, but a colon in a name must not become a term
    it 'does not treat a colon inside a card name as a term' do
      result = parse('Elspeth: Sun\'s Champion')

      expect(result).not_to be_advanced
      expect(result.free_text).to include('Elspeth:')
    end
  end

  describe 'unusable values' do
    it 'reports a non-numeric value for a numeric field instead of searching for it' do
      result = parse('mv>=banana')

      expect(result).not_to be_advanced
      expect(result.ignored).to eq(['mv>=banana'])
      expect(result.free_text).to eq('')
    end

    it 'reports an invalid color letter' do
      expect(parse('c:x').ignored).to eq(['c:x'])
    end

    it 'accepts colour names and multi-letter combinations' do
      expect(parse('c:white').terms.first.value).to eq('white')
      expect(parse('c>=wu').terms.first.value).to eq('wu')
    end

    it 'rejects an ordered comparison against an unordered rarity' do
      expect(parse('r>=special').ignored).to eq(['r>=special'])
    end

    it 'still allows an unordered rarity as an equality match' do
      expect(parse('r:special').terms.first.value).to eq('special')
    end

    it 'reports an unknown is: flag' do
      expect(parse('is:banana').ignored).to eq(['is:banana'])
      expect(parse('is:commander')).to be_advanced
    end

    it 'requires a boolean for ownership flags' do
      expect(parse('foil:maybe').ignored).to eq(['foil:maybe'])
      expect(parse('foil:true')).to be_advanced
    end
  end
end
