# The signed-in user as the game client sees it. Pass preferences: true for /me
class Api::V1::UserSerializer
  def initialize(user, preferences: false)
    @user = user
    @preferences = preferences
  end

  def as_json(*)
    json = { id: @user.id, username: @user.username, email: @user.email }
    json[:preferences] = @user.effective_preferences if @preferences
    json
  end
end
