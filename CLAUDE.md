# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run app (auto-detects device)
flutter analyze          # Lint/static analysis
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run single test
```

## Environment Setup

- `.env` file required at project root (loaded via flutter_dotenv at startup)
- Backend API: local server on port 3000
  - Android emulator: `http://10.0.2.2:3000`
  - iOS simulator: `http://127.0.0.1:3000`
  - Platform detection is handled automatically in `core/services/api_client.dart`

## Architecture

**Feature-based structure** under `lib/features/` with each feature having `data/` (models, services) and `presentation/` (pages, widgets) subdirectories.

**State management:** StatefulWidget with local state. No Provider/BLoC/Riverpod. User session persisted via SharedPreferences (`user_id` key).

**Navigation:** Direct Navigator.push/pop. No named routes. `MainContainer` (`core/widgets/main_container.dart`) is the bottom-nav hub after login, hosting Home, Game History, Groups, and Profile tabs.

**API layer:**
- `ApiClient` (Dio singleton) in `core/services/api_client.dart` — all HTTP calls go through this
- `SocketService` (Socket.IO singleton) in `core/services/socket_service.dart` — real-time score sharing in club games
- Feature-specific API services (e.g., `HomeApiService`, `GameApiService`) wrap ApiClient

## Key Domain Logic

**Bowling scoring** in `features/game/presentation/pages/frame_entry_page.dart`:
- 10 frames, each with 1-3 throws
- Strike/spare bonus scoring with lookahead (`_getNextTwoThrows`, `_getNextOneThrow`)
- 10th frame has special rules (up to 3 throws on strike/spare)
- Cumulative scores computed reactively via `_cumulativeScores` getter

**Socket events** for multiplayer: `create_room`, `join_room`, `score_update`, `start_game`

## Conventions

- UI text and comments are in Korean
- Dark mode is the default (`ThemeMode.dark` in main.dart)
- Color palette defined in `core/constants/app_colors.dart` (primary: #135BEC)
- Font: Google Fonts Lexend via `core/theme/app_theme.dart`
- Icons: Material Symbols Icons (`Symbols.*`), not standard `Icons.*`
- Use `withValues(alpha: x)` instead of deprecated `withOpacity(x)`
