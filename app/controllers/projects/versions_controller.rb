# frozen_string_literal: true

class Projects::VersionsController < InertiaController
  include ProjectReport

  before_action :set_project

  def index
    render inertia: report_props.merge(
      versions: stats.versions,
      adoption: stats.adoption,
      regression: stats.latest_regression,
      thresholds: { ratio: @project.regression_ratio.to_f, min_sessions: @project.regression_min_sessions }
    )
  end
end
