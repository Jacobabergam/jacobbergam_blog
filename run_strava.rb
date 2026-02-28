require_relative "scripts/fetch_strava.rb"

# Temporarily mock the write_data_file to avoid overwriting strava.yml
def write_data_file(payload)
  puts "Mocking write_data_file"
  "mock_path"
end

main
