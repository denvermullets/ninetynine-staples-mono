require 'rails_helper'

RSpec.describe CommanderSpellbook::FindCombos, type: :service do
  let(:card_names) { ['Dramatic Reversal', 'Isochron Scepter'] }
  let(:commanders) { [] }

  subject { described_class.call(card_names: card_names, commanders: commanders) }

  describe '#call' do
    context 'when API returns successful response' do
      let(:api_response) do
        {
          'results' => {
            'identity' => 'U',
            'included' => [
              {
                'id' => '4821-5261',
                'uses' => [
                  { 'card' => { 'name' => 'Dramatic Reversal', 'oracleId' => 'oracle-1' } },
                  { 'card' => { 'name' => 'Isochron Scepter', 'oracleId' => 'oracle-2' } }
                ],
                'produces' => [
                  { 'feature' => { 'name' => 'Infinite mana' } }
                ],
                'description' => "Step 1\nStep 2",
                'easyPrerequisites' => [{ 'template' => { 'name' => 'Mana rocks on battlefield' } }],
                'notablePrerequisites' => [],
                'requires' => [],
                'identity' => 'U',
                'legalities' => { 'commander' => 'Legal' }
              }
            ],
            'almostIncluded' => [
              {
                'id' => '999-1000',
                'uses' => [
                  { 'card' => { 'name' => 'Dramatic Reversal', 'oracleId' => 'oracle-1' } },
                  { 'card' => { 'name' => 'Some Other Card', 'oracleId' => 'oracle-3' } }
                ],
                'produces' => [{ 'feature' => { 'name' => 'Infinite tokens' } }],
                'description' => 'Do the thing',
                'easyPrerequisites' => [],
                'notablePrerequisites' => [],
                'requires' => [],
                'identity' => 'UB',
                'legalities' => { 'commander' => 'Legal' }
              }
            ]
          }
        }
      end

      before do
        response = instance_double(HTTParty::Response,
                                   success?: true,
                                   parsed_response: api_response,
                                   code: 200)
        allow(HTTParty).to receive(:post).and_return(response)
      end

      it 'returns included combos' do
        result = subject
        expect(result[:included].size).to eq(1)
        expect(result[:included].first[:spellbook_id]).to eq('4821-5261')
      end

      it 'parses combo cards' do
        combo = subject[:included].first
        expect(combo[:cards].size).to eq(2)
        expect(combo[:cards].first[:name]).to eq('Dramatic Reversal')
      end

      it 'parses results' do
        combo = subject[:included].first
        expect(combo[:results]).to eq('Infinite mana')
      end

      it 'parses steps from description' do
        combo = subject[:included].first
        expect(combo[:steps]).to eq("Step 1\nStep 2")
      end

      it 'parses prerequisites' do
        combo = subject[:included].first
        expect(combo[:prerequisites]).to eq('Mana rocks on battlefield')
      end

      it 'identifies missing cards for almost_included' do
        combo = subject[:almost_included].first
        expect(combo[:missing_cards].size).to eq(1)
        expect(combo[:missing_cards].first[:name]).to eq('Some Other Card')
      end

      it 'generates permalink' do
        combo = subject[:included].first
        expect(combo[:permalink]).to eq('https://commanderspellbook.com/combo/4821-5261')
      end
    end

    context 'when API returns almost_included with more than 2 missing cards' do
      let(:api_response) do
        {
          'results' => {
            'included' => [],
            'almostIncluded' => [
              {
                'id' => '1-2-3',
                'uses' => [
                  { 'card' => { 'name' => 'Dramatic Reversal', 'oracleId' => 'o1' } },
                  { 'card' => { 'name' => 'Card A', 'oracleId' => 'o2' } },
                  { 'card' => { 'name' => 'Card B', 'oracleId' => 'o3' } },
                  { 'card' => { 'name' => 'Card C', 'oracleId' => 'o4' } }
                ],
                'produces' => [],
                'description' => '',
                'easyPrerequisites' => [],
                'notablePrerequisites' => [],
                'requires' => [],
                'identity' => 'U',
                'legalities' => {}
              }
            ]
          }
        }
      end

      before do
        response = instance_double(HTTParty::Response, success?: true, parsed_response: api_response, code: 200)
        allow(HTTParty).to receive(:post).and_return(response)
      end

      it 'filters out combos missing more than 2 cards' do
        result = subject
        expect(result[:almost_included]).to be_empty
      end
    end

    context 'when API returns error' do
      before do
        response = instance_double(HTTParty::Response, success?: false, code: 400, body: 'Bad request')
        allow(HTTParty).to receive(:post).and_return(response)
      end

      it 'returns error hash' do
        result = subject
        expect(result[:error]).to eq('API error: 400')
      end
    end

    context 'when API times out' do
      before do
        allow(HTTParty).to receive(:post).and_raise(Net::ReadTimeout)
      end

      it 'returns timeout error' do
        result = subject
        expect(result[:error]).to eq('Commander Spellbook request timed out')
      end
    end
  end
end
