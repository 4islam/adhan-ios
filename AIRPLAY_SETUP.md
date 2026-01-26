# How to Play Adhan on AirPlay/HomePod

By default, iOS apps cannot automatically switch audio output to external speakers (like HomePods or Apple TVs) from the background without user interaction. This is a system privacy limitation.

However, you can achieve this automation using **iOS Shortcuts**.

## Step-by-Step Guide

### 1. Create the Shortcut

1. Open the **Shortcuts** app on your iPhone.
2. Tap the **+** (plus) icon to create a new shortcut.
3. Tap **Add Action** and search for **"Set Playback Destination"**.
    - Select your desired AirPlay device (e.g., "Living Room HomePod").
4. Search for **"Adhan iOS"** in the action library.
5. Select the **"Play Adhan"** action.
    - *Note: If you don't see this, open the Adhan app once to register the intent.*
6. (Optional) You can set a specific prayer name in the "Play Adhan" action if you want consistent logging, but "Regular" is fine.
7. Tap **Done** and name your shortcut (e.g., "Play Fajr on HomePod").

### 2. Automate the Shortcut

To make this run automatically at prayer times:

1. Tap the **Automation** tab at the bottom of the Shortcuts app.
2. Tap **New Automation** (or the + icon).
3. Select **"Time of Day"**.
4. Set the time to match your desired prayer time (e.g., Fajr time).
    - *Tip: You may need to update this occasionally as prayer times change, unless you use a "Sunrise/Sunset" trigger with an offset.*
5. Select **"Run Immediately"** (important so it doesn't ask for confirmation).
6. Tap **Next**.
7. Select the Shortcut you created in Step 1.
8. Tap **Done**.

## Why this is necessary

Apple restricts apps from "hijacking" audio output to external devices in the background to prevent annoyances (e.g., an ad suddenly blasting on your TV). Shortcuts, being a user-initiated system automation, bypasses this restriction.
