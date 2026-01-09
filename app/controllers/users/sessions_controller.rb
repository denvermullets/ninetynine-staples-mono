class Users::SessionsController < ApplicationController
  def new; end

  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      login(user)
      redirect_to after_login_path, notice: 'Signed in successfully.', status: :see_other
    else
      flash.now[:alert] = 'Invalid email or password. Please try again.'
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    logout
    redirect_to root_path, notice: 'Signed out successfully.', status: :see_other
  end
end
