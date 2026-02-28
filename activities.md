---
layout: activities
title: Activities
order: 3
---

<div class="page">
  <h1 class="page-title">{{ page.title }}</h1>
  <p class="section-lead">
    I love spending time outdoors, and lately, I've been focusing on staying active while soaking up the sunshine in beautiful Santa Barbara. Here is my recent training on
    <a href="https://www.strava.com" target="_blank" rel="noopener noreferrer">Strava</a>—runs and rides.
  </p>

  <h2 class="activities-list-heading">Best times</h2>
  <div class="strava-stats-board">
    {% if site.data.strava_stats %}
    <div class="stats-column">
      <div class="stats-column__header">
        <span class="stats-column__icon">🏃</span> Run PRs
      </div>
      <ul class="stats-list">
        <li>
          <span class="stats-label">Half Marathon</span>
          {% assign val = site.data.strava_stats.run.half_marathon %}
          {% if val.time == "???" or val == "???" %}
            <span class="stats-value stats-value--dim">???</span>
          {% elsif val.url and val.url != "???" %}
            <span class="stats-value"><a href="{{ val.url }}" target="_blank" rel="noopener noreferrer">{{ val.time }}</a></span>
          {% else %}
            <span class="stats-value">{{ val.time | default: val }}</span>
          {% endif %}
        </li>
        <li>
          <span class="stats-label">Marathon</span>
          {% assign val = site.data.strava_stats.run.marathon %}
          {% if val.time == "???" or val == "???" %}
            <span class="stats-value stats-value--dim">???</span>
          {% elsif val.url and val.url != "???" %}
            <span class="stats-value"><a href="{{ val.url }}" target="_blank" rel="noopener noreferrer">{{ val.time }}</a></span>
          {% else %}
            <span class="stats-value">{{ val.time | default: val }}</span>
          {% endif %}
        </li>
        <li>
          <span class="stats-label">50K Ultra</span>
          {% assign val = site.data.strava_stats.run['50k'] %}
          {% if val.time == "???" or val == "???" %}
            <span class="stats-value stats-value--dim">???</span>
          {% elsif val.url and val.url != "???" %}
            <span class="stats-value"><a href="{{ val.url }}" target="_blank" rel="noopener noreferrer">{{ val.time }}</a></span>
          {% else %}
            <span class="stats-value">{{ val.time | default: val }}</span>
          {% endif %}
        </li>
        <li>
          <span class="stats-label">50 Mile Ultra</span>
          {% assign val = site.data.strava_stats.run['50_mile'] %}
          {% if val.time == "???" or val == "???" %}
            <span class="stats-value stats-value--dim">???</span>
          {% elsif val.url and val.url != "???" %}
            <span class="stats-value"><a href="{{ val.url }}" target="_blank" rel="noopener noreferrer">{{ val.time }}</a></span>
          {% else %}
            <span class="stats-value">{{ val.time | default: val }}</span>
          {% endif %}
        </li>
      </ul>
    </div>

    <div class="stats-column">
      <div class="stats-column__header">
        <span class="stats-column__icon">🚴</span> Bike Bests
      </div>
      <ul class="stats-list stats-list--single">
        <li>
          <span class="stats-label">50 Mile Ride</span>
          {% assign val = site.data.strava_stats.bike['50_mile'] %}
          {% if val.time == "???" or val == "???" %}
            <span class="stats-value stats-value--dim">???</span>
          {% elsif val.url and val.url != "???" %}
            <span class="stats-value"><a href="{{ val.url }}" target="_blank" rel="noopener noreferrer">{{ val.time }}</a></span>
          {% else %}
            <span class="stats-value">{{ val.time | default: val }}</span>
          {% endif %}
        </li>
        <li>
          <span class="stats-label">100 Mile Ride</span>
          {% assign val = site.data.strava_stats.bike['100_mile'] %}
          {% if val.time == "???" or val == "???" %}
            <span class="stats-value stats-value--dim">???</span>
          {% elsif val.url and val.url != "???" %}
            <span class="stats-value"><a href="{{ val.url }}" target="_blank" rel="noopener noreferrer">{{ val.time }}</a></span>
          {% else %}
            <span class="stats-value">{{ val.time | default: val }}</span>
          {% endif %}
        </li>
      </ul>
    </div>
    {% endif %}
  </div>

  {% if site.data.strava and site.data.strava.activities %}
  <h2 class="activities-list-heading">Recent activities</h2>
  <div class="activity-grid">
    {% for activity in site.data.strava.activities %}
      <article class="activity-card">
        {% if activity.polyline %}
          <div class="activity-card__map-container activity-card__map-container--interactive"
               data-polyline="{{ activity.polyline | escape }}"
               data-url="{{ activity.url }}"
               aria-label="View on Strava">
          </div>
        {% elsif activity.svg_map %}
          <a href="{{ activity.url }}" class="activity-card__map-container" target="_blank" rel="noopener noreferrer" aria-label="View on Strava">
            {{ activity.svg_map }}
          </a>
        {% else %}
          <a href="{{ activity.url }}" class="activity-card__map-container activity-card__map-container--empty" target="_blank" rel="noopener noreferrer" aria-label="View on Strava">
          </a>
        {% endif %}
        <div class="activity-card__content">
          <h3 class="activity-card__title">
            <span class="activity-card__title-icon">
              {% if activity.sport_type == "Run" %}
                🏃
              {% elsif activity.sport_type == "Ride" %}
                🚴
              {% elsif activity.sport_type == "Workout" or activity.sport_type == "WeightTraining" %}
                🏋️
              {% elsif activity.sport_type == "Swim" %}
                🏊
              {% elsif activity.sport_type == "Hike" %}
                🥾
              {% elsif activity.sport_type == "Walk" %}
                🚶
              {% elsif activity.sport_type == "VirtualRide" %}
                🚴‍♂️
              {% elsif activity.sport_type == "VirtualRun" %}
                🏃‍♂️
              {% else %}
                ⏱️
              {% endif %}
            </span>
            <span class="activity-card__title-text">
              {% if activity.url %}
                <a href="{{ activity.url }}" target="_blank" rel="noopener noreferrer">{{ activity.name }}</a>
              {% else %}
                {{ activity.name }}
              {% endif %}
            </span>
          </h3>
          <p class="activity-card__meta">
            {% if activity.start_date %}{{ activity.start_date | date: "%b %-d, %Y" }}{% endif %}
            {% if activity.sport_type == "VirtualRide" or activity.sport_type == "VirtualRun" %}
              · Indoor
            {% endif %}
          </p>
          <p class="activity-card__stats">
            {% if activity.distance_km %}
              {% assign dist_mi = activity.distance_km | times: 0.621371 | round: 2 %}
              {{ dist_mi }} mi
            {% endif %}
            {% if activity.elapsed_time_minutes %}
              {% assign hrs = activity.elapsed_time_minutes | divided_by: 60 | floor %}
              {% assign mins = activity.elapsed_time_minutes | modulo: 60 | round %}
              · {% if hrs > 0 %}{{ hrs }}h {% endif %}{{ mins }}m
            {% elsif activity.moving_time_minutes %}
              {% assign hrs = activity.moving_time_minutes | divided_by: 60 | floor %}
              {% assign mins = activity.moving_time_minutes | modulo: 60 | round %}
              · {% if hrs > 0 %}{{ hrs }}h {% endif %}{{ mins }}m
            {% endif %}
            {% if activity.total_elevation_gain_m %}
              {% assign elev_ft = activity.total_elevation_gain_m | times: 3.28084 | round %}
              · {{ elev_ft }} ft gain
            {% endif %}
          </p>
        </div>
      </article>
    {% endfor %}
  </div>

  <script>
    function decodePolyline(encoded) {
      var points = [];
      var index = 0, lat = 0, lng = 0;
      while (index < encoded.length) {
        var b, shift = 0, result = 0;
        do { b = encoded.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
        lat += ((result & 1) ? ~(result >> 1) : (result >> 1));
        shift = 0; result = 0;
        do { b = encoded.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
        lng += ((result & 1) ? ~(result >> 1) : (result >> 1));
        points.push([lat / 1e5, lng / 1e5]);
      }
      return points;
    }

    document.addEventListener("DOMContentLoaded", function() {
      var mapContainers = document.querySelectorAll('.activity-card__map-container--interactive');
      if (mapContainers.length > 0) {
        var link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
        document.head.appendChild(link);

        var script = document.createElement('script');
        script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
        script.onload = function() {
          mapContainers.forEach(function(container, index) {
            var encoded = container.getAttribute('data-polyline');
            if (!encoded) return;
            var points = decodePolyline(encoded);
            if (points.length === 0) return;

            container.id = 'activity-map-' + index;

            var map = L.map(container.id, {
              zoomControl: false,
              dragging: false,
              touchZoom: false,
              scrollWheelZoom: false,
              doubleClickZoom: false,
              boxZoom: false,
              keyboard: false,
              attributionControl: false
            });

            L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
              maxZoom: 19
            }).addTo(map);

            var polyline = L.polyline(points, {
              color: '#E24C22',
              weight: 4,
              opacity: 0.85,
              lineCap: 'round',
              lineJoin: 'round'
            }).addTo(map);

            map.fitBounds(polyline.getBounds(), { paddingTopLeft: [20, 20], paddingBottomRight: [20, 155] });

            var url = container.getAttribute('data-url');
            if (url) {
              container.style.cursor = 'pointer';
              container.addEventListener('click', function() {
                window.open(url, '_blank', 'noopener,noreferrer');
              });
            }
          });
        };
        document.head.appendChild(script);
      }
    });
  </script>
  {% else %}
  <p class="section-lead">Run <code>ruby scripts/fetch_strava.rb</code> to populate recent activities.</p>
  {% endif %}
</div>
