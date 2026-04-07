#!/bin/bash
# Run requests and count how many hit each version

GATEWAY_IP="${GATEWAY_IP:-localhost:8080}"
COUNT=20

V1_COUNT=0
V2_COUNT=0

for i in $(seq 1 $COUNT); do
  RESPONSE=$(curl -s http://$GATEWAY_IP/ -H "Host: app.example.com")
  VERSION=$(echo "$RESPONSE" | grep -o 'APP_VERSION=[^",]*' | cut -d'=' -f2)
  
  if [ "$VERSION" = "v1" ]; then
    ((V1_COUNT++))
  elif [ "$VERSION" = "v2" ]; then
    ((V2_COUNT++))
  fi
done

echo "Results: v1=$V1_COUNT, v2=$V2_COUNT (total: $COUNT)"
# With 90/10 split, expect roughly 18× v1 and 2× v2