# frozen_string_literal: true

module Api
  module V1
    # Base of the ingestion API. It answers JSON only, with no session or CSRF.
    class BaseController < ActionController::API
      # Declared before the authentication on purpose: callbacks run in order, so
      # requests with an invalid or missing key are rate limited too.
      rate_limit to: 120, within: 1.minute, name: "api-key", by: -> { "key:#{Digest::SHA256.hexdigest(plain_key.to_s)}" }, with: -> { too_many_requests }
      rate_limit to: 600, within: 1.minute, name: "api-ip", by: -> { "ip:#{request.remote_ip}" }, with: -> { too_many_requests }

      before_action :authenticate_api_key

      private

      attr_reader :api_key

      def current_project
        api_key.project
      end

      # The key travels as a Bearer token or in the X-API-Key header.
      def plain_key
        bearer = request.authorization.to_s[/\ABearer\s+(\S+)/i, 1]

        (bearer || request.headers["X-API-Key"]).presence
      end

      def authenticate_api_key
        @api_key = plain_key && ApiKey.find_active(plain_key)

        if @api_key
          @api_key.touch_last_used!
        else
          response.set_header("WWW-Authenticate", "Bearer")
          render json: { message: "Invalid or missing API key." }, status: :unauthorized
        end
      end

      def too_many_requests
        response.set_header("Retry-After", "60")
        render json: { message: "Too many requests." }, status: :too_many_requests
      end
    end
  end
end
