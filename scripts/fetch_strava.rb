#!/usr/bin/env ruby
# Fetches recent Strava activities and writes _data/strava.yml for Jekyll.
#
# Required environment variables:
# - STRAVA_CLIENT_ID
# - STRAVA_CLIENT_SECRET
# - STRAVA_REFRESH_TOKEN
#
# Optional:
# - STRAVA_ACTIVITY_LIMIT (default: 6)
#
# Usage:
#   STRAVA_CLIENT_ID=... STRAVA_CLIENT_SECRET=... STRAVA_REFRESH_TOKEN=... ruby scripts/fetch_strava.rb

require "net/http"
require "json"
require "yaml"
require "uri"
require "time"
require "fileutils"

STRAVA_CLIENT_ID = ENV["STRAVA_CLIENT_ID"]
STRAVA_CLIENT_SECRET = ENV["STRAVA_CLIENT_SECRET"]
STRAVA_REFRESH_TOKEN = ENV["STRAVA_REFRESH_TOKEN"]
STRAVA_ACTIVITY_LIMIT = Integer(ENV.fetch("STRAVA_ACTIVITY_LIMIT", "6"))

def require_env!(name, value)
  return unless value.to_s.strip.empty?

  warn "Missing required environment variable: #{name}"
  exit 1
end

def post_form(uri, params)
  req = Net::HTTP::Post.new(uri)
  req.set_form_data(params)

  Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(req)
  end
end

def get_json(uri, headers = {})
  req = Net::HTTP::Get.new(uri)
  headers.each { |k, v| req[k] = v }

  Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.request(req)
  end
end

def fetch_activity_details(access_token, activity_id)
  uri = URI("https://www.strava.com/api/v3/activities/#{activity_id}")
  response = get_json(uri, { "Authorization" => "Bearer #{access_token}" })
  
  unless response.is_a?(Net::HTTPSuccess)
    warn "Strava activity details request failed (#{response.code}): #{response.body}"
    return nil
  end

  JSON.parse(response.body)
rescue JSON::ParserError => e
  warn "Failed to parse Strava activity details response: #{e.message}"
  nil
end

def exchange_refresh_token
  uri = URI("https://www.strava.com/oauth/token")
  response = post_form(
    uri,
    {
      "client_id" => STRAVA_CLIENT_ID,
      "client_secret" => STRAVA_CLIENT_SECRET,
      "refresh_token" => STRAVA_REFRESH_TOKEN,
      "grant_type" => "refresh_token"
    }
  )

  unless response.is_a?(Net::HTTPSuccess)
    warn "Strava token exchange failed (#{response.code}): #{response.body}"
    exit 1
  end

  JSON.parse(response.body)
rescue JSON::ParserError => e
  warn "Failed to parse Strava token response: #{e.message}"
  exit 1
end

def fetch_activities(access_token, per_page)
  uri = URI("https://www.strava.com/api/v3/athlete/activities")
  uri.query = URI.encode_www_form("per_page" => per_page)

  response = get_json(uri, { "Authorization" => "Bearer #{access_token}" })
  unless response.is_a?(Net::HTTPSuccess)
    warn "Strava activities request failed (#{response.code}): #{response.body}"
    exit 1
  end

  JSON.parse(response.body)
rescue JSON::ParserError => e
  warn "Failed to parse Strava activities response: #{e.message}"
  exit 1
end

def number_or_nil(value)
  return nil if value.nil?

  Float(value)
rescue ArgumentError, TypeError
  nil
end

def decode_polyline(polyline)
  return [] unless polyline && !polyline.empty?
  points = []
  index = 0
  lat = 0
  lng = 0

  while index < polyline.length
    b = 0
    shift = 0
    result = 0
    loop do
      b = polyline[index].ord - 63
      index += 1
      result |= (b & 0x1f) << shift
      shift += 5
      break if b < 0x20
    end
    dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
    lat += dlat

    shift = 0
    result = 0
    loop do
      b = polyline[index].ord - 63
      index += 1
      result |= (b & 0x1f) << shift
      shift += 5
      break if b < 0x20
    end
    dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
    lng += dlng

    points << [lat / 1e5, lng / 1e5]
  end
  points
end

def generate_svg(points)
  return nil if points.nil? || points.empty?
  
  lats = points.map(&:first)
  lngs = points.map(&:last)
  
  min_lat, max_lat = lats.min, lats.max
  min_lng, max_lng = lngs.min, lngs.max
  
  lat_diff = max_lat - min_lat
  lng_diff = max_lng - min_lng
  
  lat_diff = 0.0001 if lat_diff == 0
  lng_diff = 0.0001 if lng_diff == 0

  width = 100.0
  height = 100.0
  
  avg_lat_rad = (min_lat + max_lat) / 2.0 * Math::PI / 180.0
  aspect_ratio = (lng_diff * Math.cos(avg_lat_rad)) / lat_diff
  
  if aspect_ratio > 1
    height = 100.0 / aspect_ratio
  else
    width = 100.0 * aspect_ratio
  end
  
  padding = 5.0
  
  path_data = points.map.with_index do |(lat, lng), i|
    x = padding + ((lng - min_lng) / lng_diff) * width
    y = padding + height - ((lat - min_lat) / lat_diff) * height
    "#{i == 0 ? 'M' : 'L'} #{x.round(2)} #{y.round(2)}"
  end.join(" ")
  
  total_width = (width + padding * 2).round(2)
  total_height = (height + padding * 2).round(2)
  
  "<svg viewBox=\"0 0 #{total_width} #{total_height}\" xmlns=\"http://www.w3.org/2000/svg\" class=\"strava-route\"><path d=\"#{path_data}\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"3.5\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"
end

def normalize_activity(activity)
  id = activity["id"]
  distance_m = number_or_nil(activity["distance"])
  moving_time_s = number_or_nil(activity["moving_time"])
  elapsed_time_s = number_or_nil(activity["elapsed_time"])
  avg_speed_mps = number_or_nil(activity["average_speed"])
  max_speed_mps = number_or_nil(activity["max_speed"])
  elevation_m = number_or_nil(activity["total_elevation_gain"])

  polyline = activity.dig("map", "summary_polyline")
  svg_map = generate_svg(decode_polyline(polyline))

  {
    "id" => id,
    "name" => activity["name"],
    "type" => activity["type"],
    "sport_type" => activity["sport_type"],
    "start_date" => activity["start_date"],
    "distance_km" => distance_m ? (distance_m / 1000.0).round(2) : nil,
    "moving_time_minutes" => moving_time_s ? (moving_time_s / 60.0).round(1) : nil,
    "elapsed_time_minutes" => elapsed_time_s ? (elapsed_time_s / 60.0).round(1) : nil,
    "average_speed_kph" => avg_speed_mps ? (avg_speed_mps * 3.6).round(2) : nil,
    "max_speed_kph" => max_speed_mps ? (max_speed_mps * 3.6).round(2) : nil,
    "total_elevation_gain_m" => elevation_m ? elevation_m.round(1) : nil,
    "location_city" => activity["location_city"],
    "location_state" => activity["location_state"],
    "location_country" => activity["location_country"],
    "url" => id ? "https://www.strava.com/activities/#{id}" : nil,
    "svg_map" => svg_map,
    "polyline" => (polyline && !polyline.empty?) ? polyline : nil
  }.compact
end

def write_data_file(payload)
  data_dir = File.join(__dir__, "..", "_data")
  FileUtils.mkdir_p(data_dir)
  out_path = File.join(data_dir, "strava.yml")
  File.write(out_path, payload.to_yaml)
  out_path
end

def format_time(seconds)
  hours = seconds / 3600
  minutes = (seconds % 3600) / 60
  secs = seconds % 60
  
  if hours > 0
    sprintf("%d:%02d:%02d", hours, minutes, secs)
  else
    sprintf("%d:%02d", minutes, secs)
  end
end

def parse_time(time_str)
  return 999999999 if time_str == "???" || time_str.nil?
  
  parts = time_str.split(":").map(&:to_i)
  if parts.length == 3
    parts[0] * 3600 + parts[1] * 60 + parts[2]
  elsif parts.length == 2
    parts[0] * 60 + parts[1]
  else
    999999999
  end
end

def update_stats(activities, access_token)
  stats_file = File.join(__dir__, "..", "_data", "strava_stats.yml")
  stats = YAML.load_file(stats_file) rescue {
    "run" => { 
      "half_marathon" => { "time" => "???", "url" => "???" }, 
      "marathon" => { "time" => "???", "url" => "???" }, 
      "50k" => { "time" => "???", "url" => "???" }, 
      "50_mile" => { "time" => "???", "url" => "???" } 
    },
    "bike" => { 
      "50_mile" => { "time" => "???", "url" => "???" }, 
      "100_mile" => { "time" => "???", "url" => "???" } 
    }
  }

  # Ensure migration of old format just in case
  ["run", "bike"].each do |sport|
    next unless stats[sport]
    stats[sport].each do |k, v|
      if v.is_a?(String)
        stats[sport][k] = { "time" => v, "url" => "???" }
      end
    end
  end

  stats_updated = false

  activities.each do |activity|
    # Only fetch details for specific types to find best efforts
    type = activity["type"] || activity["sport_type"]
    
    if type == "Run" || type == "VirtualRun" || type == "Ride" || type == "VirtualRide"
      details = fetch_activity_details(access_token, activity["id"])
      next unless details && details["best_efforts"]
      
      details["best_efforts"].each do |effort|
        name = effort["name"]
        time = effort["moving_time"] || effort["elapsed_time"]
        
        if type == "Run" || type == "VirtualRun"
          key = case name
                when "Half Marathon" then "half_marathon"
                when "Marathon" then "marathon"
                when "50k" then "50k"
                when "50 mile" then "50_mile"
                else nil
                end
          
          if key && time < parse_time(stats["run"][key]["time"])
            stats["run"][key]["time"] = format_time(time)
            stats["run"][key]["url"] = "https://www.strava.com/activities/#{activity['id']}"
            stats_updated = true
            puts "New Run PR! #{name}: #{stats["run"][key]["time"]}"
          end
        elsif type == "Ride" || type == "VirtualRide"
          key = case name
                when "50 mile" then "50_mile"
                when "100 mile" then "100_mile"
                else nil
                end
                
          if key && time < parse_time(stats["bike"][key]["time"])
            stats["bike"][key]["time"] = format_time(time)
            stats["bike"][key]["url"] = "https://www.strava.com/activities/#{activity['id']}"
            stats_updated = true
            puts "New Bike PR! #{name}: #{stats["bike"][key]["time"]}"
          end
        end
      end
    end
  end

  # Always write the file so it exists for the workflow (git add); first run or no PRs
  # would otherwise leave it missing and cause the workflow to fail.
  File.write(stats_file, stats.to_yaml)
  puts "Updated strava_stats.yml with new personal records!" if stats_updated
end

def main
  require_env!("STRAVA_CLIENT_ID", STRAVA_CLIENT_ID)
  require_env!("STRAVA_CLIENT_SECRET", STRAVA_CLIENT_SECRET)
  require_env!("STRAVA_REFRESH_TOKEN", STRAVA_REFRESH_TOKEN)

  token_data = exchange_refresh_token
  access_token = token_data["access_token"]
  refreshed_token = token_data["refresh_token"]

  require_env!("access_token", access_token)
  require_env!("refresh_token", refreshed_token)

  # Fetch more activities initially so we have enough after filtering
  activities = fetch_activities(access_token, 30)

  # Only keep runs, rides, and swims
  allowed_types = ["Run", "Ride", "Swim", "VirtualRide", "VirtualRun"]
  filtered_activities = activities.select do |activity|
    allowed_types.include?(activity["type"]) || allowed_types.include?(activity["sport_type"])
  end.first(STRAVA_ACTIVITY_LIMIT)

  normalized = filtered_activities.map { |activity| normalize_activity(activity) }

  payload = {
    "fetched_at" => Time.now.utc.iso8601,
    "activities" => normalized
  }

  out_path = write_data_file(payload)
  puts "Wrote #{normalized.size} activities to #{out_path}"
  
  # Update all-time stats based on recent activities
  update_stats(normalized, access_token)
  
  puts "NOTE: Strava may rotate refresh tokens. Save this value if it changes:"
  puts "STRAVA_REFRESH_TOKEN=#{refreshed_token}"
end

main
