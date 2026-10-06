# frozen_string_literal: true

class ApiKeysController < InertiaController
  # Creates a key. The plain text is shown once, since only its digest is stored.
  def create
    project = Current.user.projects.find(params[:project_id])
    api_key, plain = ApiKey.generate(project, name: params[:name].presence)

    flash.inertia[:new_key] = { name: api_key.name, key: plain }
    redirect_to edit_project_path(project)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_project_path(project), inertia: { errors: e.record.errors }
  end

  # Revokes a key. It stays listed as revoked, and stops working at once.
  def destroy
    api_key = Current.user.api_keys.find(params[:id])
    api_key.revoke! if api_key.active?

    redirect_to edit_project_path(api_key.project_id), notice: "API key revoked."
  end
end
