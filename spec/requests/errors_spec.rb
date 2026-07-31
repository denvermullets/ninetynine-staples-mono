require 'rails_helper'

RSpec.describe 'Errors', type: :request do
  describe 'turbo_stream requests' do
    # without these templates a 500 inside a turbo_stream request dies in the
    # failsafe renderer and the user sees nothing at all
    %w[/404 /422 /500].each do |path|
      it "renders a toast stream for #{path}" do
        get path, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('<turbo-stream action="append" target="toasts">')
      end
    end
  end
end
