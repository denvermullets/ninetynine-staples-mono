require 'rails_helper'

RSpec.describe 'Users::Registrations', type: :request do
  let(:params) do
    { user: { email: 'new@example.com', username: 'newuser', password: 'password123',
              password_confirmation: 'password123' } }
  end

  before do
    # The failure path renders users/registrations/new inside the application
    # layout, which needs the built tailwind.css that CI does not have. Only the
    # status matters here, so swap the render for a bare head.
    allow_any_instance_of(Users::RegistrationsController).to receive(:render) do |controller, *, **options|
      controller.head(options.fetch(:status, :ok))
    end
  end

  it 'creates the user and redirects' do
    expect { post user_registration_path, params: params }.to change(User, :count).by(1)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(boxsets_path)
  end

  it 'rejects a username that is already taken' do
    create(:user, username: 'newuser')

    expect { post user_registration_path, params: params }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects a username that differs only by case' do
    create(:user, username: 'NewUser')

    expect { post user_registration_path, params: params }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects a username that slips past validation but hits the unique index' do
    create(:user, username: 'newuser')
    allow_any_instance_of(User).to receive(:valid?).and_return(true)

    expect { post user_registration_path, params: params }.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
  end
end
