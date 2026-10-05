require 'rails_helper'

RSpec.describe 'Dashboard jobs', type: :request do
  include ActiveJob::TestHelper

  def log_in(as)
    post login_path, params: { email: as.email, password: 'password123' }
  end

  describe 'POST recalculate_deck_totals' do
    it 'queues the job for an admin' do
      log_in(create(:user, role: 9001))

      expect { post dashboard_recalculate_deck_totals_path }.to have_enqueued_job(RecalculateDeckTotals)
      expect(response).to redirect_to('/jobs')
    end

    it 'refuses a regular user' do
      log_in(create(:user))

      expect { post dashboard_recalculate_deck_totals_path }.not_to have_enqueued_job
      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses a logged-out visitor' do
      expect { post dashboard_reset_collections_path }.not_to have_enqueued_job
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
