require "net/http"
require "json"
require "uri"

# Load current stats to get the access token logic
require_relative "scripts/fetch_strava.rb"

# Exchange token just to get a fresh access token
token_data = exchange_refresh_token()
access_token = token_data["access_token"]

# Fetch latest 1 activity
activities = fetch_activities(access_token, 1)

if activities.any?
  activity_id = activities.first["id"]
  puts "Fetching details for activity #{activity_id}..."
  
  details = fetch_activity_details(access_token, activity_id)
  
  if details && details["best_efforts"]
    puts "\nFound Best Efforts array:"
    puts JSON.pretty_generate(details["best_efforts"].first(2))
    puts "... (#{details["best_efforts"].size} total efforts)"
  else
    puts "\nNo best_efforts array found in the response."
  end
end
