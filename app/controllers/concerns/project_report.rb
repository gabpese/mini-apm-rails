# frozen_string_literal: true

# What the read-only pages of a project share. All of them accept ?days=7|30|90.
module ProjectReport
  private

  # Someone else's project is a 404, so its existence is not revealed.
  def set_project
    @project = Current.user.projects.find(params[:project_id] || params[:id])
  end

  def days
    requested = params[:days].to_i

    ProjectStats::PERIODS.include?(requested) ? requested : ProjectStats::DEFAULT_PERIOD
  end

  def stats
    @stats ||= ProjectStats.new(@project, days: days)
  end

  def report_props
    { project: @project.slice(:id, :name), days: days, periods: ProjectStats::PERIODS }
  end
end
