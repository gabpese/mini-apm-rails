namespace :apm do
  desc "Fill a demo project with realistic fictional usage, errors and a crash regression " \
       "(options as env vars: USER_EMAIL, PROJECT, DAYS, USERS, SEED, API_KEY, FRESH=1)"
  task simulate: :environment do
    email = ENV["USER_EMAIL"]
    user = email ? User.find_by(email: email) : User.order(:id).first
    abort "No user found. Create an account first, or pass USER_EMAIL=email." unless user

    simulation = ApmSimulation.new(
      user: user,
      project_name: ENV.fetch("PROJECT", ApmSimulation::DEFAULT_PROJECT_NAME),
      days: Integer(ENV.fetch("DAYS", 30)),
      users: Integer(ENV.fetch("USERS", 150)),
      seed: Integer(ENV.fetch("SEED", 42)),
      api_key: ENV["API_KEY"].presence,
      fresh: ENV["FRESH"].present?
    )

    puts "Sending events to \"#{ENV.fetch("PROJECT", ApmSimulation::DEFAULT_PROJECT_NAME)}\"..."
    result = simulation.call do |stored, total|
      print "\r#{stored}/#{total} events"
      $stdout.flush
    end
    puts

    puts format("%-9s %9s %8s %11s", "Version", "Sessions", "Crashes", "Crash rate")
    ApmSimulation.summary(result.project).each do |version, sessions, crashes, rate|
      puts format("%-9s %9d %8d %11s", version, sessions, crashes, rate ? "#{rate}%" : "-")
    end

    if result.new_api_key
      puts "\nAPI key created. Save it now, it will not be shown again:"
      puts "  #{result.new_api_key}"
    end
  rescue ApmSimulation::Error => e
    abort e.message
  end
end
