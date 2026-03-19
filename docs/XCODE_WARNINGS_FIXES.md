# Xcode warnings — fixes

Apply these in your project (the files may be at `~/GuiltyPleasureTreats` or `~/Projects/GuiltyPleasureTreats`).

---

## 1. `-ld_classic is deprecated`

**Cause:** The classic linker is being used (often by a Swift package like Stripe).

**Fix A — Xcode UI:**  
Build Settings → search "Other Linker Flags" → **Other Linker Flags (OTHER_LDFLAGS)** → remove any `-ld_classic` or `-Wl,-ld_classic`.

**Fix B — If it comes from a package:**  
Update the Stripe (or other) package to a version that doesn’t require the classic linker. Or in your **target**’s Build Settings set **Other Linker Flags** to `$(inherited)` only (no extra flags).

---

## 2. VercelService.swift — unused `uid` (lines 52 and 72)

**Message:** `Immutable value 'uid' was never used; consider replacing with '_' or removing it`

**Fix:** Replace the unused parameter `uid` with `_` in both places.

Example: if you have something like:
```swift
.someMethod { uid in
    return something
}
```
change to:
```swift
.someMethod { _ in
    return something
}
```

Search in `VercelService.swift` for `uid` in closures (e.g. around lines 52 and 72) and change `uid` to `_`.

---

## 3. ProfileView.swift — unnecessary `try` (line 184)

**Message:** `No calls to throwing functions occur within 'try' expression`

**Fix:** Remove the `try` keyword from that expression.

Example: change `let x = try someNonThrowingCall()` to `let x = someNonThrowingCall()`.

---

## 4. SettingsView.swift — unnecessary `try` (line 188)

**Message:** `No calls to throwing functions occur within 'try' expression`

**Fix:** Remove the `try` keyword from that expression (same as ProfileView).

---

## Summary

| Issue | File | Fix |
|-------|------|-----|
| ld_classic deprecated | Build Settings | Remove `-ld_classic` from Other Linker Flags |
| Unused `uid` | VercelService.swift:52, :72 | Replace `uid` with `_` in the closure(s) |
| Unnecessary try | ProfileView.swift:184 | Remove `try` |
| Unnecessary try | SettingsView.swift:188 | Remove `try` |
