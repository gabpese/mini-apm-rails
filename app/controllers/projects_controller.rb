# frozen_string_literal: true

class ProjectsController < InertiaController
  include ProjectReport

  before_action :set_project, except: :create

  # The overview of a project.
  def show
    render inertia: report_props.merge(
      totals: stats.totals,
      daily: stats.daily,
      features: stats.top_features,
      environment: stats.environment,
      regression: stats.latest_regression,
      min_ram_mb: @project.min_ram_mb,
      min_os: @project.min_os
    )
  end

  # Creates a project and its first API key, shown once on the settings page.
  def create
    project = Current.user.projects.build(project_params)

    if project.save
      _, plain = ApiKey.generate(project, name: "Default")
      flash.inertia[:new_key] = { name: "Default", key: plain }

      redirect_to edit_project_path(project)
    else
      redirect_to dashboard_path, inertia: { errors: project.errors }
    end
  end

  # The settings of a project.
  def edit
    render inertia: {
      project: @project.slice(:id, :name, :min_ram_mb, :min_os, :regression_min_sessions)
        .merge(regression_ratio: @project.regression_ratio.to_f),
      # The id breaks ties between keys created in the same second.
      keys: @project.api_keys.order(created_at: :desc, id: :desc).map { |key| key_props(key) }
    }
  end

  def update
    if @project.update(project_params)
      redirect_to edit_project_path(@project), notice: "Project updated."
    else
      redirect_to edit_project_path(@project), inertia: { errors: @project.errors }
    end
  end

  def destroy
    @project.destroy!

    redirect_to dashboard_path, notice: "Project deleted."
  end

  private

  def project_params
    params.permit(:name, :min_ram_mb, :min_os, :regression_ratio, :regression_min_sessions)
  end

  # Never includes the digest of the key.
  def key_props(key)
    {
      id: key.id,
      name: key.name,
      prefix: key.key_prefix,
      last_used_at: key.last_used_at&.iso8601,
      revoked_at: key.revoked_at&.iso8601,
      created_at: key.created_at.iso8601
    }
  end
end
