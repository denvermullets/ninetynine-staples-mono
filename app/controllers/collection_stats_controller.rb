# The analytics dashboard arrives in two requests, not one.
#
# Every panel is a separate aggregate over the viewer's whole collection, so rendering all ten at
# once costs about 720ms of SQL at twenty thousand cards. #show serves the shell - headline numbers
# and the tab bar - off a single query, and #section serves one tab of panels into its turbo frame.
class CollectionStatsController < ApplicationController
  def show
    @section = opening_section
    @stats = dashboard
    return unless @stats[:missing]

    redirect_to collections_stats_path(params[:username]), alert: 'Collection not found'
  end

  # Turbo asks for the frame; anything else is a bookmark or a reload after a tab advanced the URL,
  # and a bare partial is not a page - those go to the shell with the tab already open.
  def section
    return head :not_found unless CollectionStats::Dashboard.section?(params[:section])
    return redirect_to shell_path unless turbo_frame_request?

    @section = params[:section]
    @stats = dashboard(section: @section)
    return redirect_to shell_path if @stats[:missing]

    render partial: 'collection_stats/section',
           locals: { stats: @stats, section: @section, username: params[:username],
                     collection_id: params[:collection_id] }
  end

  private

  # collection_id is forwarded on both paths. Dropping it on the section request is the one mistake
  # that looks like it works: the tab would quietly report on every collection while the shell above
  # it reports on one.
  def dashboard(section: nil)
    CollectionStats::Dashboard.call(
      username: params[:username], viewer: current_user,
      collection_id: params[:collection_id], section: section
    )
  end

  # ?section= survives a reload, so the shell honours it and falls back rather than 404ing - the tab
  # is presentation, and a stale bookmark should still show the dashboard
  def opening_section
    return params[:section] if CollectionStats::Dashboard.section?(params[:section])

    CollectionStats::Dashboard::DEFAULT_SECTION
  end

  def shell_path
    collections_stats_path(params[:username], section: params[:section],
                                              collection_id: params[:collection_id])
  end
end
