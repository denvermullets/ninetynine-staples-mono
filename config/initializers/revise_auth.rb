ReviseAuth.configure do |config|
  # Customize the params for registration and update profile.
  # config.sign_up_params += [:time_zone]
  # config.update_params += [:time_zone]

  config.sign_up_params += [ :username ]
  config.minimum_password_length = 10
end
