require 'rails_helper'

RSpec.describe Follow, type: :model do
  let(:alice) { create(:user, username: 'alice') }
  let(:bob) { create(:user, username: 'bob') }

  it 'links a follower to the user they follow, one way' do
    create(:follow, follower: alice, followed: bob)

    expect([alice.following.to_a, bob.followers.to_a, bob.following.to_a]).to eq([[bob], [alice], []])
    expect([alice.following?(bob), bob.following?(alice), alice.following?(nil)]).to eq([true, false, false])
  end

  it 'allows one follow per pair' do
    create(:follow, follower: alice, followed: bob)

    expect(build(:follow, follower: alice, followed: bob)).not_to be_valid
  end

  it 'does not let a user follow themselves' do
    expect(build(:follow, follower: alice, followed: alice)).not_to be_valid
  end

  it 'goes when either user does' do
    create(:follow, follower: alice, followed: bob)
    create(:follow, follower: bob, followed: alice)

    expect { alice.destroy! }.to change(described_class, :count).from(2).to(0)
  end
end
