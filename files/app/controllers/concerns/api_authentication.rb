# Bearer token authentication for API and MCP endpoints.
#
# Reads the Authorization header, finds the user by token, checks deactivation,
# and sets Current.user directly (no Session). Returns 401 JSON on failure.
#
#   class API::BaseController < ActionController::API
#     include APIAuthentication
#   end
#
module APIAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :require_api_authentication
  end

  private

  def require_api_authentication
    token = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip

    if token.blank?
      render json: { error: "Valid API token required" }, status: :unauthorized
      return
    end

    user = APIToken.authenticate(token)

    if user.nil?
      render json: { error: "Invalid API token" }, status: :unauthorized
      return
    end

    if user.deactivated?
      render json: { error: "Account deactivated" }, status: :unauthorized
      return
    end

    Current.user = user
  end
end
