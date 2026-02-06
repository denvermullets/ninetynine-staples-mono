class UserMailer < ApplicationMailer
  def password_reset(user, token)
    @user = user
    @token = token

    mail(to: user.email, subject: 'Reset your password')
  end

  def email_confirmation(user, token)
    @user = user
    @token = token

    mail(to: user.email, subject: 'Confirm your email address')
  end
end
