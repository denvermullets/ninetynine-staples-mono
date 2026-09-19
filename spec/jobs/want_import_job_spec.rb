require 'rails_helper'

# What gets resolved and added is covered by the BulkImport and ProxyImport specs; this is about which
# one runs and what goes back out on the user's stream.
RSpec.describe WantImportJob, type: :job do
  let(:user) { create(:user) }
  let(:stream) { "user_#{user.id}_notifications" }
  let(:src) { "/collections/#{user.username}/wants" }

  before do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
  end

  describe 'a pasted decklist' do
    before { create(:magic_card, name: 'Sol Ring', scryfall_oracle_id: SecureRandom.uuid) }

    it 'adds the cards to the user' do
      described_class.new.perform(user.id, src, decklist: "1 Sol Ring\n1 Not A Card")

      expect(user.want_list_items.count).to eq(1)
    end

    it 'broadcasts the report, with the lines to fix left for the textarea' do
      described_class.new.perform(user.id, src, decklist: "1 Sol Ring\n2 Not A Card")

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        stream, target: 'want_import', partial: 'collection_wants/import',
                locals: { result: a_hash_including(success: true), text: '2 Not A Card' }
      )
    end

    it 'broadcasts a reload of the list' do
      described_class.new.perform(user.id, src, decklist: '1 Sol Ring')

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        stream, target: 'want_items', partial: 'collection_wants/reload_items', locals: { src: src }
      )
    end

    it 'broadcasts a success toast' do
      described_class.new.perform(user.id, src, decklist: '1 Sol Ring')

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
        stream, target: 'toasts', html: a_string_including('bg-accent-50', 'Added 1 card')
      )
    end
  end

  describe 'a paste over the limit' do
    let(:text) { Array.new(WantList::BulkImport::MAX_CARDS + 1) { |i| "1 Card #{i}" }.join("\n") }

    it 'hands the whole paste back with the error, and leaves the list alone' do
      described_class.new.perform(user.id, src, decklist: text)

      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).once.with(
        stream, target: 'want_import', partial: 'collection_wants/import',
                locals: { result: a_hash_including(success: false), text: text }
      )
      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
        stream, target: 'toasts', html: a_string_including('bg-accent-100', 'at most')
      )
    end
  end

  describe 'with no decklist' do
    it "adds the user's proxies" do
      card = create(:magic_card, scryfall_oracle_id: SecureRandom.uuid)
      create(:collection_magic_card, collection: create(:collection, user: user), magic_card: card,
                                     quantity: 0, proxy_quantity: 1)

      described_class.new.perform(user.id, src)

      expect(user.want_list_items.pluck(:magic_card_id)).to eq([card.id])
    end
  end

  # the broadcasts above are stubbed, so this is the one place the panel is rendered outside a request
  it 'renders the report panel without a request' do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to).and_call_original

    expect { described_class.new.perform(user.id, src, decklist: '1 Not A Card') }.not_to raise_error
  end

  it 'enqueues on collection_updates' do
    expect { described_class.perform_later(user.id, src) }.to have_enqueued_job.on_queue('collection_updates')
  end
end
