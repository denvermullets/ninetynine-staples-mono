require 'rails_helper'

RSpec.describe Scryfall::OracleTagsImporter, type: :service do
  let(:removal_id) { SecureRandom.uuid }
  let(:spot_id) { SecureRandom.uuid }
  let(:doom_id) { SecureRandom.uuid }
  let(:sweeper_id) { SecureRandom.uuid }

  let(:bolt) { SecureRandom.uuid }
  let(:blade) { SecureRandom.uuid }
  let(:wrath) { SecureRandom.uuid }

  def tag_record(id, slug, parents: [], taggings: [], aliases: [])
    {
      'object' => 'tag', 'type' => 'oracle', 'id' => id, 'slug' => slug, 'label' => slug.tr('-', ' '),
      'description' => nil, 'parent_ids' => parents, 'child_ids' => [], 'aliases' => aliases,
      'taggings' => taggings.map { |oracle_id| { 'oracle_id' => oracle_id, 'weight' => 'median' } }
    }
  end

  # removal is an umbrella with no direct taggings, like the real file
  let(:records) do
    [
      tag_record(removal_id, 'removal'),
      tag_record(spot_id, 'spot-removal', parents: [removal_id], taggings: [bolt], aliases: ['spot']),
      tag_record(doom_id, 'doom-blade', parents: [spot_id], taggings: [blade]),
      tag_record(sweeper_id, 'sweeper', parents: [removal_id], taggings: [wrath])
    ]
  end

  def import(recs = records)
    described_class.call(records: recs)
  end

  def tag(slug) = OracleTag.find_by!(slug: slug)

  describe 'a first import' do
    it 'writes tags, taggings and counts' do
      result = import

      expect(result).to include(tag_count: 4, tagging_count: 3)
      expect(tag('spot-removal')).to have_attributes(scryfall_id: spot_id, label: 'spot removal', aliases: ['spot'])
      expect(CardOracleTag.from_scryfall.pluck(:scryfall_oracle_id)).to contain_exactly(bolt, blade, wrath)
    end

    it 'builds the closure through every level of the hierarchy' do
      import

      ancestors = OracleTagAncestor.where(descendant_id: tag('doom-blade').id)
                                   .to_h { |row| [row.ancestor_id, row.depth] }
      expect(ancestors).to eq(tag('doom-blade').id => 0, tag('spot-removal').id => 1, tag('removal').id => 2)
    end

    it 'reports every tagged card as changed' do
      expect(import[:changed_oracle_ids]).to contain_exactly(bolt, blade, wrath)
    end
  end

  describe 'a repeat import of the same file' do
    it 'changes nothing and reports nothing changed' do
      import

      expect { @result = import }.not_to(change { [OracleTag.count, CardOracleTag.count, OracleTagAncestor.count] })
      expect(@result[:changed_oracle_ids]).to be_empty
    end
  end

  describe 'when Scryfall drops a tagging' do
    it 'deletes it, reports the card, and leaves user taggings alone' do
      import
      user_tagging = create(:card_oracle_tag, :by_user, oracle_tag: tag('sweeper'), scryfall_oracle_id: bolt)

      records[3]['taggings'] = []
      result = import

      expect(CardOracleTag.from_scryfall.where(scryfall_oracle_id: wrath)).to be_empty
      expect(result[:changed_oracle_ids]).to include(wrath)
      expect(user_tagging.reload).to be_persisted
    end
  end

  describe 'when Scryfall drops a tag' do
    it 'deletes the tag' do
      import

      import(records.first(3))

      expect(OracleTag.find_by(slug: 'sweeper')).to be_nil
    end

    it 'keeps a tag a user has applied, as a user tag' do
      import
      create(:card_oracle_tag, :by_user, oracle_tag: tag('sweeper'), scryfall_oracle_id: bolt)

      import(records.first(3))

      expect(tag('sweeper')).to have_attributes(source: 'user', scryfall_id: nil)
    end
  end

  # a card tagged doom-blade carries removal through the closure, so moving doom-blade changes its roles
  describe 'when a tag moves in the hierarchy' do
    it 'reports the cards carrying it as changed' do
      import

      records[2]['parent_ids'] = [removal_id]
      result = import

      expect(result[:changed_oracle_ids]).to contain_exactly(blade)
    end
  end

  describe 'when Scryfall hands a slug to a different tag' do
    it 'moves the slug without tripping the unique index' do
      import

      records[1]['slug'] = 'sweeper'
      records[3]['slug'] = 'spot-removal'
      import

      expect(tag('sweeper').scryfall_id).to eq(spot_id)
      expect(tag('spot-removal').scryfall_id).to eq(sweeper_id)
    end

    it 'renames a user tag that held the slug' do
      user_tag = create(:oracle_tag, :user_created, slug: 'sweeper')

      import

      expect(user_tag.reload.slug).to eq("sweeper-user-#{user_tag.id}")
      expect(tag('sweeper').scryfall_id).to eq(sweeper_id)
    end
  end

  # an empty or unreadable file must not read as "Scryfall deleted every tag"
  it 'refuses an empty file and rolls back' do
    import

    expect { import([]) }.to raise_error(described_class::EmptyFileError)
    expect(CardOracleTag.count).to eq(3)
  end
end
