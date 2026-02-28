def decode_polyline(polyline)
  return [] unless polyline
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
  return nil if points.empty?
  
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
  
  "<svg viewBox=\"0 0 #{total_width} #{total_height}\" xmlns=\"http://www.w3.org/2000/svg\" class=\"strava-route\"><path d=\"#{path_data}\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></svg>"
end

# Test polyline
poly = "kz|vEpzhmU^j@L?z@T"
pts = decode_polyline(poly)
puts generate_svg(pts)
