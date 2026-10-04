require 'rails_helper'
require 'support/api/v1_helpers'

# a throwaway controller on the real base, routed only inside with_routing, so the error envelope is
# tested through the full stack rather than against a stub
module Api
  module V1
    class ErrorProbeController < BaseController
      def missing_record
        User.find(-1)
      end

      def missing_param
        params.require(:deck)
        head :ok
      end

      def paged
        records, meta = paginate(User.order(:id))
        render json: { data: records.map(&:id), meta: meta }
      end
    end
  end
end

RSpec.describe 'API v1 errors', type: :request do
  include_context 'api v1 request'

  around do |example|
    with_routing do |set|
      set.draw do
        namespace :api, defaults: { format: :json } do
          namespace :v1 do
            get 'probe/missing_record', to: 'error_probe#missing_record'
            get 'probe/missing_param', to: 'error_probe#missing_param'
            get 'probe/paged', to: 'error_probe#paged'
          end
        end
      end

      example.run
    end
  end

  it 'renders a missing record as a 404 envelope' do
    get '/api/v1/probe/missing_record', headers: api_headers

    expect_api_error(:not_found, 'not_found')
  end

  it 'renders a missing param as a 422 envelope' do
    get '/api/v1/probe/missing_param', headers: api_headers

    expect_api_error(:unprocessable_content, 'parameter_missing')
    expect(json_body.dig('error', 'message')).to include('deck')
  end

  describe 'pagination' do
    before { create_list(:user, 3) }

    it 'pages the scope and reports the total' do
      get '/api/v1/probe/paged', params: { page: 2, per_page: 2 }, headers: api_headers

      expect(json_body['data'].size).to eq(1)
      expect(json_body['meta']).to eq('page' => 2, 'per_page' => 2, 'total' => 3)
    end

    it 'caps per_page at 100 and defaults bad input' do
      get '/api/v1/probe/paged', params: { page: 0, per_page: 500 }, headers: api_headers

      expect(json_body['meta']).to include('page' => 1, 'per_page' => 100)

      get '/api/v1/probe/paged', params: { per_page: 'lots' }, headers: api_headers

      expect(json_body['meta']).to include('per_page' => 25)
    end
  end
end
