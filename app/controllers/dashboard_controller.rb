# frozen_string_literal: true

# The dashboard is the list of the user's projects, each with a small summary
# of the last 30 days.
class DashboardController < InertiaController
  def index
    projects = Current.user.projects.order(created_at: :desc, id: :desc).map do |project|
      project.slice(:id, :name).merge(ProjectStats.new(project).summary)
    end

    render inertia: { projects: projects, period: ProjectStats::DEFAULT_PERIOD }
  end
end
