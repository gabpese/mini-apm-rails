require "rails_helper"

RSpec.describe "db/seeds.rb" do
  def seed(env = {})
    original = ENV.to_h
    ENV.update(env)
    load Rails.root.join("db/seeds.rb")
  ensure
    ENV.replace(original)
  end

  it "creates nothing without the demo variables" do
    expect { seed("DEMO_USER_EMAIL" => nil, "DEMO_USER_PASSWORD" => nil) }.not_to change(User, :count)
    expect { seed("DEMO_USER_EMAIL" => "demo@example.com", "DEMO_USER_PASSWORD" => nil) }.not_to change(User, :count)
  end

  it "creates the verified demo account that can sign in" do
    seed("DEMO_USER_EMAIL" => "demo@example.com", "DEMO_USER_PASSWORD" => "a-long-demo-password")

    user = User.find_by!(email: "demo@example.com")
    expect(user).to have_attributes(name: "Demo User", verified: true)
    expect(User.authenticate_by(email: "demo@example.com", password: "a-long-demo-password")).to eq(user)
  end

  it "runs again without duplicating, and updates the password" do
    seed("DEMO_USER_EMAIL" => "demo@example.com", "DEMO_USER_PASSWORD" => "a-long-demo-password")

    expect { seed("DEMO_USER_EMAIL" => "demo@example.com", "DEMO_USER_PASSWORD" => "another-long-password") }
      .not_to change(User, :count)
    expect(User.authenticate_by(email: "demo@example.com", password: "another-long-password")).to be_present
  end
end
