require 'rails_helper'

RSpec.describe WantList::Remove do
  it 'destroys the row and reports the card name' do
    item = create(:want_list_item)

    result = described_class.call(item: item)

    expect(result).to eq(success: true, name: item.magic_card.name)
    expect(WantListItem.exists?(item.id)).to be(false)
  end
end
