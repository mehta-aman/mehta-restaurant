#!/bin/bash
set -e

# Mehta Restaurant — One-Command Production Web Deployment
echo "================================================"
echo "🚀 Building Mehta Restaurant Web Release..."
echo "================================================"

cd "$(dirname "$0")"

flutter build web --release \
  --dart-define=SUPABASE_URL=https://esjlwtlaqmnjlyctbjgm.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVzamx3dGxhcW1uamx5Y3RiamdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE5NzkwODksImV4cCI6MjEwNzU1NTA4OX0.Nv-OOvwv5n_BscP4UXaxcBopoxgF3QQReSAxQZKLYbw

echo ""
echo "================================================"
echo "☁️  Deploying to Firebase Hosting..."
echo "================================================"

npx firebase-tools deploy --only hosting

echo ""
echo "================================================"
echo "✅ Deployed successfully to https://mehta-restaurant.web.app"
echo "================================================"
