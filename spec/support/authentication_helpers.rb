# frozen_string_literal: true

module AuthenticationHelpers
  def self.signed_cookie(name, value)
    cookie_jar = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
    cookie_jar.signed[name] = value
    cookie_jar[name]
  end

  module Request
    def sign_in(user)
      session = user.sessions.create!
      cookies[:session_token] = AuthenticationHelpers.signed_cookie(:session_token, session.id)
    end

    def sign_out
      cookies[:session_token] = ""
    end
  end

  module System
    # A real browser only takes a cookie for the page it is on, so it opens one first.
    def sign_in(user)
      session = user.sessions.create!
      visit rails_health_check_path
      page.driver.browser.manage.add_cookie(
        name: "session_token",
        value: CGI.escape(AuthenticationHelpers.signed_cookie(:session_token, session.id))
      )
    end

    def sign_out
      page.driver.browser.manage.delete_cookie("session_token")
    end
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers::Request, type: :request
  config.include AuthenticationHelpers::System, type: :system
end
