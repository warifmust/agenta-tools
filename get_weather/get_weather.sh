#!/usr/bin/env bash
set -euo pipefail

city=$(printf '%s' "$AGENTA_TOOL_PARAMS" | jq -r '.city')

# Step 1: Geocode the city (curl -G --data-urlencode handles URL-encoding safely)
geocode_res=$(curl -s -G "https://geocoding-api.open-meteo.com/v1/search" \
  --data-urlencode "name=$city" --data "count=1")

lat=$(printf '%s' "$geocode_res" | jq -r '.results[0].latitude // empty')
lon=$(printf '%s' "$geocode_res" | jq -r '.results[0].longitude // empty')
resolved_name=$(printf '%s' "$geocode_res" | jq -r '.results[0].name // empty')

if [ -z "$lat" ] || [ -z "$lon" ]; then
  echo "{\"error\": \"City '$city' not found. Please check the spelling.\"}"
  exit 0
fi

# Step 2: Get weather data
weather_res=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code")

temp=$(printf '%s' "$weather_res" | jq -r '.current.temperature_2m')
humidity=$(printf '%s' "$weather_res" | jq -r '.current.relative_humidity_2m')
wind=$(printf '%s' "$weather_res" | jq -r '.current.wind_speed_10m')

echo "{\"city\": \"$resolved_name\", \"temperature\": $temp, \"humidity\": $humidity, \"wind_speed\": $wind}"