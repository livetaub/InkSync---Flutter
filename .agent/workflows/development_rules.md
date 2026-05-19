---
description: Project development guidelines and rules
---

# Development Guidelines

## Dev Server Rules

**IMPORTANT: Never run the dev server automatically!**

The user prefers to start the Flutter dev server manually from their own terminal. The agent should:

1. **NEVER** run `flutter run`, `flutter run -d chrome`, or any dev server commands
2. **NEVER** run `npm run dev`, `npm start`, or equivalent dev server commands
3. After making code changes, inform the user that they can test by running the dev server themselves
4. Wait for user feedback about how the changes look/work

## Testing Changes

When you make code changes:
1. Make the edits to the code files
2. Inform the user what was changed
3. Ask the user to test by running their dev server manually
4. Wait for their feedback before making additional changes
