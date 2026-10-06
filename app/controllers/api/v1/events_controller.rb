# frozen_string_literal: true

module Api
  module V1
    class EventsController < BaseController
      def create
        payload = parse_body
        errors = EventBatchSchema.errors_for(payload)

        if errors.any?
          render json: { message: "The batch is invalid.", errors: errors }, status: :unprocessable_content
        else
          accepted = EventIngestor.new(current_project).ingest(payload.fetch("events"))
          render json: { accepted: accepted }, status: :accepted
        end
      end

      private

      # Read from the raw body: the schema must see the request exactly as it was
      # sent, without the params Rails adds (controller, action, wrapped keys).
      def parse_body
        JSON.parse(request.raw_post)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
