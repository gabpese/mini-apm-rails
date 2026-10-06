# Creates the account used by a demo, only when DEMO_USER_EMAIL and
# DEMO_USER_PASSWORD are set. Nothing is created otherwise, so no password lives
# in the code. Safe to run again: it updates the account of that email.
#
#   DEMO_USER_EMAIL=demo@example.com DEMO_USER_PASSWORD='a-password-of-12+' bin/rails db:seed
#   bin/rails apm:simulate
email = ENV["DEMO_USER_EMAIL"].presence
password = ENV["DEMO_USER_PASSWORD"].presence

if email && password
  User.find_or_initialize_by(email: email).tap do |user|
    user.update!(name: "Demo User", password: password, verified: true)
  end
end
