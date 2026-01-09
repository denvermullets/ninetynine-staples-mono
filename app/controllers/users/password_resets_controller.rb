class Users::PasswordResetsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    user = User.find_by(email: params[:email])

    if user
      token = user.generate_token_for(:password_reset)
      UserMailer.password_reset(user, token).deliver_later
    end

    redirect_to login_path,
                notice: 'If an account exists with that email, you will receive password reset instructions.',
                status: :see_other
  end

  def edit
    @user = User.find_by_token_for(:password_reset, params[:token])

    return unless @user.nil?

    redirect_to new_password_reset_path, alert: 'Password reset link is invalid or has expired.'
  end

  def update
    @user = User.find_by_token_for(:password_reset, params[:token])

    if @user.nil?
      redirect_to new_password_reset_path, alert: 'Password reset link is invalid or has expired.'
      return
    end

    if @user.update(password_params)
      login(@user)
      redirect_to after_login_path, notice: 'Your password has been reset successfully.', status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
