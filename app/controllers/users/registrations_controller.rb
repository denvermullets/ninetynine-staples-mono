class Users::RegistrationsController < ReviseAuth::RegistrationsController
  # overriding the default revise_auth controller since we want to create a default collection
  # on registration

  def new
    @user = User.new
  end

  def create
    @user = User.new
    super

    return unless @user.persisted?

    Collection.create!(name: 'Default', description: 'Starter binder', user_id: @user.id)
  end
end
