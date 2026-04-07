## 1. Window Resize

- [x] 1.1 Fix `OnboardingWindowController.ensureWindowCanFitContentSize()`: remove the guard that prevents shrinking, rename to `resizeWindowToFitContentSize()`, allow bidirectional resize with `NSAnimationContext` (duration ~0.4s to match SwiftUI spring)
- [x] 1.2 Verify window shrinks from 700→600 when navigating from LLMConfig/STTConfig back to HotkeySetup or other steps

## 2. ScrollView for Config Forms

- [x] 2.1 Wrap `LLMConfigStepView.configFields` in `ScrollView(.vertical, showsIndicators: false)`
- [x] 2.2 Wrap `STTConfigStepView.configFields` in `ScrollView(.vertical, showsIndicators: false)`

## 3. Step Indicator Fix

- [x] 3.1 Change `OnboardingStep.indicatorSteps` from static array to a method/computed property that accepts sttMode, include `.sttConfig` when sttMode is `.remote`
- [x] 3.2 Update `OnboardingWindow.stepIndicator` to pass sttMode and handle dynamic dot count with animation

## 4. URL Validation

- [x] 4.1 Add URL format validation to `LLMConfigStepView.canContinue`: apiBase must start with `http://` or `https://` and parse via `URL(string:)`
- [x] 4.2 Add the same URL validation to `STTConfigStepView.canContinue`

## 5. Permissions Flicker Fix

- [x] 5.1 In `PermissionsStepView.requestAccessibility()`, remove the synchronous state assignment; only update `accessibilityGranted` once inside the async Task after the delay recheck

## 6. Style Consistency

- [x] 6.1 Standardize `HotkeySetupStepView` primary button maxWidth from 180 to 200
- [x] 6.2 Standardize `CompleteStepView` primary button maxWidth from 240 to 200
- [x] 6.3 Fix `CompleteStepView` padding from `.padding(40)` to `.padding(.horizontal, 40)`
