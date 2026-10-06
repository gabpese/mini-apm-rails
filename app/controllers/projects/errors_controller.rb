# frozen_string_literal: true

class Projects::ErrorsController < InertiaController
  include ProjectReport

  before_action :set_project

  def index
    render inertia: report_props.merge(groups: stats.error_groups)
  end
end
