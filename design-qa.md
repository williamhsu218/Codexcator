# Design QA

## Current scope

- Native SwiftUI menu-bar app for personal use on macOS.
- Displays Codex 5-hour and 7-day quota windows, reset times, reset-credit count, and concrete expiry times.
- Omits the 5-hour row when Codex does not return that window.
- Includes a native Stay Awake control with Caffeine-compatible duration choices.
- Supports English and Simplified Chinese.
- Includes a complete macOS App Icon asset set.
- Does not include an app extension, App Group entitlement, or desktop widget.

## Visual checks

- Uses native San Francisco typography, monospaced digits, semantic weights, and keyboard/focus behavior.
- Uses macOS semantic text, separator, and track colors over a system material surface so the panel follows Light and Dark appearance automatically.
- Keeps the cyan/green quota distinction with softer system teal and system green accents instead of fixed neon colors.
- Uses native Liquid Glass for the menu panel and footer actions on macOS 26+, with the adaptive material surface retained as the macOS 14–15 fallback.
- Preserves quota dividers, progress-bar rhythm, reset-credit grouping, footer alignment, and compact menu-bar presentation.
- Quota rows expose combined accessibility labels and avoid duplicate VoiceOver output.
- Uses system orange only for the Stay Awake icon, active state, switch tint, and behavior/duration menus so the utility remains visually separate from quota status.
- Keeps the Stay Awake control compact while exposing separate display-behavior and duration menus in both English and Simplified Chinese.

## Runtime checks

- Build and launch are verified through `./script/build_and_run.sh --verify`.
- The menu-bar process remains active after launch.
- Live Codex refresh is checked through unified logging.
- Local quota caching uses the user's Application Support directory and requires no App Group.
- `pmset -g assertions` confirms that Stay Awake always creates a Codexcator-owned system-sleep assertion, adds a display-sleep assertion only for “Keep display awake,” and removes both on stop or expiry.
- When Stay Awake is active, the menu bar title shows a leading template `cup.and.saucer.fill` icon; it disappears immediately when the feature stops.
- The popover uses a compact 340-point desktop width, with reset expiries arranged in a two-column grid and the reset-count badge trailing the section title.

## Localization checks

- English and Simplified Chinese resources cover the app, menu-bar panel, settings, and error states.
- Both languages keep Asia/Shanghai as the quota reset and expiry timezone while using locale-appropriate date text.

## App Icon checks

- Master artwork: `/Users/willhsu/Documents/CodexIndicator/Design/AppIcon-master.png`
- Production asset catalog: `/Users/willhsu/Documents/CodexIndicator/Assets.xcassets/AppIcon.appiconset`
- The cyan/lime dual-gauge mark remains recognizable at 16 px, uses no text or third-party logo, and preserves safe padding for macOS rounded-square masking.
