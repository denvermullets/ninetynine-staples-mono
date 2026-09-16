require 'rails_helper'

RSpec.describe OracleTag, type: :model do
  describe 'self ancestry' do
    # otag: joins the closure table, so a tag without its own depth-0 row could never be searched
    it 'gives every new tag a depth-0 row pointing at itself' do
      tag = create(:oracle_tag)

      expect(OracleTagAncestor.where(ancestor_id: tag.id, descendant_id: tag.id, depth: 0)).to exist
    end
  end

  describe '.resolve' do
    let!(:tag) do
      create(:oracle_tag, slug: 'mana-rock', label: 'mana rock', aliases: %w[rock manarock])
    end

    it 'finds by slug' do
      expect(described_class.resolve('mana-rock')).to eq(tag)
    end

    it 'finds by label, ignoring case' do
      expect(described_class.resolve('Mana Rock')).to eq(tag)
    end

    it 'finds by alias' do
      expect(described_class.resolve('manarock')).to eq(tag)
    end

    it 'reads spaces as hyphens when the label is the slug' do
      giant = create(:oracle_tag, slug: 'tutor-creature-giant', label: 'tutor-creature-giant')

      expect(described_class.resolve('tutor creature giant')).to eq(giant)
    end

    it 'returns nil for blank or unknown values' do
      expect(described_class.resolve('')).to be_nil
      expect(described_class.resolve('not-a-tag')).to be_nil
    end

    it 'respects an enclosing scope' do
      tag.update!(disabled: true)

      expect(described_class.enabled.resolve('mana-rock')).to be_nil
    end
  end

  describe '#tagger_url' do
    it 'links a Scryfall tag back to Tagger' do
      tag = build(:oracle_tag, slug: 'spot-removal')

      expect(tag.tagger_url).to eq('https://tagger.scryfall.com/tags/card/spot-removal')
    end

    it 'has nowhere to link a user tag' do
      expect(build(:oracle_tag, :user_created).tagger_url).to be_nil
    end
  end
end
