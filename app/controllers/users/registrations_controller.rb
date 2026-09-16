class Users::RegistrationsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    if params.dig(:user, :website).present?
      redirect_to after_login_path, notice: 'Account created successfully.'
      return
    end

    @user = User.new(registration_params)

    if save_user
      if Rails.env.development?
        @user.confirm!
      else
        token = @user.generate_token_for(:email_confirmation)
        UserMailer.email_confirmation(@user, token).deliver_later
      end
      Collection.create!(name: 'Default', description: 'Starter binder', user_id: @user.id)
      login(@user)
      redirect_to after_login_path, notice: 'Account created successfully.', status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  # The uniqueness validation races with concurrent sign-ups; the unique index
  # on LOWER(username) is the real guard, so surface its failure like a
  # validation error instead of a 500.
  def save_user
    @user.save
  rescue ActiveRecord::RecordNotUnique
    @user.errors.add(:username, :taken)
    false
  end

  def registration_params
    params.require(:user).permit(:email, :username, :password, :password_confirmation)
  end
end
