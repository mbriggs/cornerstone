module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
      deny_deactivated_user if Current.session&.user&.deactivated?
    end

    def deny_deactivated_user
      terminate_session
      redirect_to new_session_path, alert: "Your access has been disabled."
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.active.includes(:user).find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.fullpath
      redirect_to new_session_path
    end

    def after_authentication_url
      url = session.delete(:return_to_after_authenticating)

      if url.present?
        # Standard: only allow relative paths, reject protocol-relative URLs
        return url if url.start_with?("/") && !url.start_with?("//")
      end

      root_url
    end

    def start_new_session_for(user)
      return_to = session[:return_to_after_authenticating]
      reset_session
      session[:return_to_after_authenticating] = return_to if return_to
      session = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
      Current.session = session
      cookies.signed[:session_id] = {
        value: session.id,
        httponly: true,
        same_site: :lax,
        secure: Rails.env.production?,
        expires: Session::SESSION_DURATION.from_now
      }
      session
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
