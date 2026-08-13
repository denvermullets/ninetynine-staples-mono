require 'rails_helper'

RSpec.describe CollectionStats::PrintingLabels, type: :service do
  subject(:labels) { described_class.call(magic_card_ids: [card.id]) }

  let(:card) { create(:magic_card) }

  # no factories for these - the join tables are built by hand, same as spec/requests/boxsets_spec.rb
  def frame(name)
    MagicCardFrameEffect.create!(magic_card: card, frame_effect: FrameEffect.find_or_create_by!(name: name))
  end

  def finish(name)
    MagicCardFinish.create!(magic_card: card, finish: Finish.find_or_create_by!(name: name))
  end

  it 'names a printing after the frame it is in' do
    frame('showcase')

    expect(labels).to eq({ card.id => ['showcase'] })
  end

  # "312 borderless" is somewhere to look; "312" on its own is a number
  it 'reads a multi-word effect the way somebody would say it' do
    frame('extendedart')

    expect(labels[card.id]).to eq(['extendedart'])
  end

  # a foil is how you bought the printing, not which printing it is, and labelling half a set "foil"
  # says nothing. Etched is a different object.
  it 'takes etched from the finishes and leaves nonfoil and foil alone' do
    finish('etched')
    finish('foil')
    finish('nonfoil')

    expect(labels[card.id]).to eq(['etched'])
  end

  it 'puts the frame before the finish, the way it would be said out loud' do
    frame('showcase')
    finish('etched')

    expect(labels[card.id]).to eq(%w[showcase etched])
  end

  it 'has nothing to say about a plain printing' do
    expect(labels).to eq({})
  end

  it 'asks nothing when there is no page to label' do
    expect(described_class.call(magic_card_ids: [])).to eq({})
  end
end
