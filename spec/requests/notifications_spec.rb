require 'rails_helper'

# GET /notifications renders a layout CI cannot build, so only the writes are requested here.
RSpec.describe 'Notifications', type: :request do
  let(:user) { create(:user, username: 'reader') }
  let(:trade) { create(:trade, recipient: user) }
  let!(:notification) { user.notifications.create!(kind: 'trade_proposed', notifiable: trade) }

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'password123' }
  end

  describe 'PATCH /notifications/:id/read' do
    it 'sends a logged-out visitor to the login page' do
      patch read_notification_path(notification)

      expect(response).to redirect_to(login_path)
      expect(notification.reload).not_to be_read
    end

    it 'marks it read and goes on to the trade' do
      sign_in(user)

      patch read_notification_path(notification)

      expect(response).to redirect_to(trade_path(trade))
      expect(notification.reload).to be_read
    end

    it "404s on someone else's notification" do
      sign_in(create(:user, username: 'snoop'))

      patch read_notification_path(notification)

      expect(response).to have_http_status(:not_found)
      expect(notification.reload).not_to be_read
    end
  end

  describe 'PATCH /notifications/read_all' do
    it "marks every one of the user's notifications read, and nobody else's" do
      mine = user.notifications.create!(kind: 'trade_accepted', notifiable: trade)
      theirs = trade.proposer.notifications.create!(kind: 'trade_accepted', notifiable: trade)
      sign_in(user)

      patch read_all_notifications_path

      expect(response).to redirect_to(notifications_path)
      expect([notification, mine].map { |n| n.reload.read? }).to all(be(true))
      expect(theirs.reload).not_to be_read
    end
  end
end
