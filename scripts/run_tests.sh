#!/bin/bash

# Adhan TimeZone Logic Validator
# Compiles core logic and tests into a standalone executable.

echo "🔨 Compiling Adhan TimeZone Tests..."

# Get absolute paths
BASE_DIR="/Users/nislam/Documents/Projects/Adhan iOS/Adhan iOS"
PRAYER_TIMES="$BASE_DIR/Models/PrayerTimes.swift"
TEST_FILE="$BASE_DIR/Tests/TimeZoneTests.swift"
OUTPUT="/tmp/adhan_tz_tests"

# Check if files exist
if [ ! -f "$PRAYER_TIMES" ]; then
    echo "❌ Error: PrayerTimes.swift not found at $PRAYER_TIMES"
    exit 1
fi

if [ ! -f "$TEST_FILE" ]; then
    echo "❌ Error: TimeZoneTests.swift not found at $TEST_FILE"
    exit 1
fi

# Compile using swiftc with TEST_RUNNER flag
swiftc -D TEST_RUNNER "$PRAYER_TIMES" "$TEST_FILE" -o "$OUTPUT"

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful. Running tests..."
    "$OUTPUT"
    RESULT=$?
    rm "$OUTPUT"
    exit $RESULT
else
    echo "❌ Compilation failed."
    exit 1
fi
