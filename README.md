# Adhan iOS 🕋

> **A Premium, Feature-Rich Prayer Times Application for iOS.**

Adhan iOS is designed to provide highly accurate prayer times, beautiful Adhan playback, and deep customization. Built with a focus on visual excellence and robust tracking, it ensures you never miss a prayer.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2016.0+-blue.svg)](https://apple.com/ios)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🌟 Sister Version

This project is part of a cross-platform effort. Check out the Android version here:
👉 **[Adhan Android](https://github.com/4islam/adhan-android)**

---

## ✨ Key Features

### 🕒 Pro-Level Scheduling

- **High-Accuracy Calculations:** Support for multiple calculation methods (Ahmadiyya, MWL, ISNA, etc.).
- **Smart Adjustments:** Tahajjud offset, high-latitude methods, and Hanafi/Shafii Asr timing.
- **Dynamic Dashboard:** Real-time countdowns, sun/moon positions, and elegant date navigation.

### 🔊 Advanced Audio Control

- **Per-Day Overrides:** Long-press any prayer day to set unique audio outputs, volumes, and fade durations.
- **Fade-In Logic:** Smooth Adhan starts to prevent sudden loud sounds.
- **Background Playback:** Robust playback even when the app is minimized or the screen is locked.

### 📊 Past Events (Diagnostics)

- **Deep Tracking:** Monitor exactly when Adhans are scheduled, triggered, and played.
- **Device Insights:** Verfiy which speaker/output was used for each event.
- **Fail-Safe Logging:** Capture playback glitches or configuration errors to ensure reliability.

### 🎨 Visual Excellence

- **Glassmorphism Design:** Modern, premium UI with smooth gradients and interactive elements.
- **Astronomy-Driven Backgrounds:** UI reacts to the current position of the Sun and Moon.
- **Widgets:** Quickly check upcoming prayer times from your Home Screen.

---

## 🛠 Tech Stack

- **UI:** SwiftUI
- **Hardware:** AVFoundation (Audio), CoreLocation (GPS), UserNotifications
- **Architecture:** MVVM (Model-View-ViewModel)
- **Persistence:** AppStorage & Structured JSON Overrides

---

## 🚀 Getting Started

1. **Clone the repo:**

   ```bash
   git clone https://github.com/4islam/adhan-ios.git
   ```

2. **Open in Xcode:**
   Open `Adhan iOS.xcodeproj` or the `.xcworkspace` if available.
3. **Build & Run:**
   Target a physical iPhone or the Simulator (Note: Notifications and background audio work best on physical devices).

---

## 🤝 Contribution

Contributions are welcome! Please feel free to submit Pull Requests or open issues for feature requests.

---

## 📜 Credits

- **Calculation Logic:** Ported from [PrayTime.js](http://praytimes.org/) by Hamid Zarrabi-Zadeh.
- **License:** The calculation core is licensed under [Creative Commons 3.0 (BY-NC-SA)](https://creativecommons.org/licenses/by-nc-sa/3.0/).

---

## 📜 License

This project is licensed under the MIT License.
