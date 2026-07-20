# Design: Guest Mode with Timer Access

## Overview

Allow users to access the timer feature immediately without signing in. Mods and Profile tabs require authentication.

## Current Flow

```
App Start → Auth Gate (StreamBuilder) → Signed in? → MainShellPage
                                           No → AuthPage (required)
```

## New Flow

```
App Start → MainShellPage (always)
              ↓
         Timer tab (index 0): Always accessible
         Mods tab (index 1): Check auth → AuthPage if not signed in
         Profile tab (index 2): Check auth → AuthPage if not signed in
```

## Changes Required

### 1. `lib/main.dart`

**Current:**
- Uses `StreamBuilder` on `authStateChanges` to gate access
- Shows `AuthPage` if not signed in, `MainShellPage` if signed in

**New:**
- Remove `StreamBuilder` auth gate
- Always show `MainShellPage` as `home:`
- Keep `AuthService` instantiation for other pages

### 2. `lib/pages/main_shell_page.dart`

**Current:**
- Tab navigation switches between Timer, Mods, Profile without auth checks

**New:**
- Import `AuthService`
- On `onDestinationSelected`, check if user is tapping Mods (index 1) or Profile (index 2)
- If not authenticated, show `AuthPage` as a modal route
- After auth completes, navigate to the selected tab
- Timer tab (index 0) always works without auth

### 3. `lib/pages/auth_page.dart`

**Current:**
- No back navigation (auth is the only entry point)

**New:**
- Accept optional `onBackPressed` callback
- Show back button when callback is provided
- After successful sign-in, pop with result indicating auth success

## Auth State Check

Use `AuthService().currentUserId` to check if user is signed in:
- `null` → not signed in → show auth page
- non-null → signed in → allow navigation

## Edge Cases

- User signs in from Mods tab → return to Mods tab
- User signs in from Profile tab → return to Profile tab
- User dismisses auth page → return to Timer tab
- User signs out from Profile → next tap on Mods/Profile shows auth page

## Testing

1. Launch app → should land on Timer tab immediately
2. Tap Timer tab → works without auth
3. Tap Mods tab → shows AuthPage
4. Sign in → returns to Mods tab
5. Tap Profile tab → works (already signed in)
6. Sign out from Profile → next Mods/Profile tap shows AuthPage
