class Users::EmailConfirmationsController < ApplicationController
  before_action :authenticate_user!, only: :create

  def show
    user = User.find_by_token_for(:email_confirmation, params[:token])

    if user
      user.confirm!
      login(user) unless logged_in?
      redirect_to after_login_path, notice: 'Email confirmed successfully!'
    else
      redirect_to root_path, alert: 'Invalid or expired confirmation link.'
    end
  end

  def create
    token = current_user.generate_token_for(:email_confirmation)
    UserMailer.email_confirmation(current_user, token).deliver_later
    redirect_to root_path, notice: 'Confirmation email sent!'
  end
end
