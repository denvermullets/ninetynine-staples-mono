# Who the signed-in user follows, and the follow / unfollow buttons on other users' pages.
#
# Session-scoped like the trade builder: the follower is always current_user, and who they are
# following rides in the body rather than the path - a username with a dot in it does not survive
# a :username path segment.
#
# The buttons sit in a turbo frame of their own, so the redirect back swaps just the button. The
# list on the index sits in one too, which is also what lets the request spec ask for it without
# the layout.
class FollowsController < ApplicationController
  TABS = %w[following followers].freeze
  PER_PAGE = 50

  before_action :authenticate_user!

  def index
    @tab = TABS.include?(params[:tab]) ? params[:tab] : 'following'
    @counts = { 'following' => current_user.following.count, 'followers' => current_user.followers.count }
    @following_ids = current_user.active_follows.pluck(:followed_id).to_set
    @pagy, @users = @counts[@tab].zero? ? [nil, []] : page_of(current_user.public_send(@tab))
  end

  def create
    user = User.find_by('LOWER(username) = ?', params[:username].to_s.strip.downcase)
    return redirect_back_or_to following_path, alert: 'No user by that name.' unless user
    return redirect_back_or_to following_path, alert: 'You cannot follow yourself.' if user.id == current_user.id

    current_user.active_follows.find_or_create_by!(followed: user)
    redirect_back_or_to following_path, notice: "You are following #{user.username}."
  rescue ActiveRecord::RecordNotUnique
    # a double click raced the first insert - they are following, which is what was asked for
    redirect_back_or_to following_path
  end

  def destroy
    user = User.find_by(username: params[:username])
    current_user.active_follows.where(followed: user).delete_all if user

    redirect_back_or_to following_path, notice: ("You unfollowed #{user.username}." if user)
  end

  private

  def page_of(users)
    pagy(:offset, users.order(Arel.sql('LOWER(users.username)')), count: @counts[@tab], limit: PER_PAGE)
  end
end
