## Project Overview
- Name: coffeecore
- Stack: Flutter (Dart)
- Target Platforms: Android, Web, iOS

## Build & Quality Commands
- Check Code / Linting: `flutter analyze`
- Run Tests: `flutter test`
- Format Code: `dart format .`
- Clean Build: `flutter clean && flutter pub get`

## Architecture Guide
- Folder Structure: Layer-First
  - `lib/models/` (Data models)
  - `lib/screens/` (UI Pages)
  - `lib/widgets/` (Reusable UI components)
  - `lib/services/` (API and Database logic)

## Coding Conventions
- Prefer early returns to minimize deep widget/code nesting.
- Always implement `const` constructors on UI widgets where applicable.
- Do not leave manual print statements; use `developer.log()` for debugging.
- Use explicit types rather than relying heavily on `var` or `dynamic`.

## Deployment & Verification Rules
- Before concluding any task, automatically run `flutter analyze` to guarantee zero errors or warnings.
- Run `dart format .` on any updated or newly created Dart file.
