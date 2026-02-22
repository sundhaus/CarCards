#!/bin/bash

# HeatCheck Sync & Build Script
# Pulls latest from GitHub and builds the project

PROJECT_DIR="/Users/jbsund/Documents/HeatCheck/HeatCheck"
SCHEME="HeatCheck"
XCODEPROJ="$PROJECT_DIR/HeatCheck.xcodeproj"

echo ""
echo "🔥 HeatCheck Sync & Build"
echo "========================="
echo ""

# Navigate to project
cd "$PROJECT_DIR" || { echo "❌ Project directory not found"; exit 1; }

# Pull latest
echo "⬇️  Pulling latest from GitHub..."
git fetch origin
git reset --hard origin/main
echo ""

# Build
echo "🔨 Building project..."
echo ""

xcodebuild build \
  -project "$XCODEPROJ" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS' \
  -quiet 2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED|⚠️|❌"

BUILD_RESULT=${PIPESTATUS[0]}

echo ""
if [ $BUILD_RESULT -eq 0 ]; then
  echo "✅ Build succeeded! Open Xcode and hit Run."
else
  echo "❌ Build failed — check errors above."
fi

echo ""
