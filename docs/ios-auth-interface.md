# iOS authentication interface

Research checked against Apple and Google primary sources on 2026-07-15.

## Decision

Use an Apple-native, grouped settings hierarchy. For the paired provider controls, do not mix a system Apple layout with a custom Google layout. The alignment-first implementation should use two custom visible buttons built from each provider's official artwork, while keeping AuthenticationServices and GoogleSignIn for the actual flows. Apple explicitly lists aligning logos across multiple sign-in buttons as a valid reason to create a custom Sign in with Apple button. App Review evaluates custom Apple buttons, so the official artwork and proportions are mandatory. [Apple: Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)

Make both controls full width and 44 pt high, which is Apple's default and recommended iOS height and also satisfies the general 44 x 44 pt interaction target. Use the same 10 to 12 pt continuous corner radius and 10 to 12 pt vertical gap. In Dark Mode, use white-filled Apple and Google buttons. In Light Mode, use Apple's white outlined appearance beside Google's light appearance. These combinations preserve each brand while giving the pair similar visual weight. [Apple: Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple), [Apple: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Google: branding guidelines](https://developers.google.com/identity/branding-guidelines)

## Screenshot review: 2026-07-15 11:21

The revision is materially better: the outer rectangles are the same width and height, the shadow has gone, and the white Apple style is correct on a dark background. The remaining imbalance is internal:

- The Apple system control centers its logo and title as one group. The custom Google control pins the G to the leading inset while independently centering the title. The rectangles align, but the icon columns do not, so the pair still reads as two unrelated components.
- The Apple label is larger and heavier. Some difference is prescribed by the brands, but the Google implementation increases it by using SF at 14 pt. Google's current requirement is Google Sans Medium at 14/20.
- At 52 pt, both buttons are larger than Apple's recommended 44 pt default. The extra height makes the controls dominate a Settings section and exaggerates the typography difference.
- The Google G is loaded by reaching into the SDK's internal resource bundle. That path is not the published branding interface and can change with an SDK update. Vendor Google's downloadable, pre-approved current asset instead.

This cannot be solved reliably by adding more `frame`, padding, or clipping modifiers to the current hybrid. Either accept each provider's independent system geometry, or use the documented custom path for both. Because exact pairing is an explicit design goal here, use the custom path for both.

## Authentication buttons

- Apple still recommends the system control because it guarantees approved proportions, localization, and VoiceOver labeling. If exact cross-provider alignment is not required, `SignInWithAppleButton` remains the lowest-risk choice. For this interface, use Apple's documented custom alternative with official vector or 44 pt PNG artwork. Never use an SF Symbol or a hand-drawn Apple logo. Use only `Sign in with Apple`, keep the logo and title black on the white button, and preserve the custom-button ratio of 44 pt height to 19 pt system title. Keep at least 8 percent of the button width between the title and trailing edge. [Apple: Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)
- A custom Google button is allowed. Google still recommends its SDK control, but explicitly permits a custom button when the branding rules are followed. Use the official downloadable full-color G, the exact text `Sign in with Google`, Google Sans Medium at 14/20, and the current light-theme tokens: `#FFFFFF` fill, `#747775` 1 px inside stroke, and `#1F1F1F` text. On iOS, preserve 16 pt before the logo, 12 pt after it, and 16 pt after the text. Do not recolor, redraw, stretch, or use an outdated G. [Google: branding guidelines](https://developers.google.com/identity/branding-guidelines)
- Give both custom controls the same layout skeleton: a visually centered title and an official logo in a fixed leading column. Apple's guidance permits adjusting the logo inset to align it with other authentication logos. Do not force the two labels to use the same font or point size, because their brand rules differ.
- Keep both buttons approximately the same size and visual weight. This is a requirement from both providers, not merely a visual preference. Align the outer rectangles and baselines, while preserving each brand's internal logo and typography rules. [Apple: Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple), [Google: branding guidelines](https://developers.google.com/identity/branding-guidelines)
- Avoid adding a shared custom shadow. It makes the Google button glow in Dark Mode and produces unequal emphasis. Let the fill, stroke, and pressed state communicate interactivity.
- The project now pins the current GoogleSignIn-iOS 9.2.0 release. Keep GoogleSignIn for the authentication flow even when the visible surface is custom. [Google: iOS integration](https://developers.google.com/identity/sign-in/ios/sign-in), [GoogleSignIn-iOS 9.2.0](https://github.com/google/GoogleSignIn-iOS/releases/tag/9.2.0)

## Account hierarchy

- Use an inset-grouped list or the same visual grammar: a compact identity row, a subscription section, and a separate account-actions section. Apple points to grouped lists for settings because headers, footers, and spacing establish hierarchy. [Apple: Lists and tables](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables), [Apple: Settings](https://developer.apple.com/design/human-interface-guidelines/settings)
- Signed out: show one short benefit statement, then the two sign-in controls. Apple recommends explaining the value of sign-in and delaying it until it benefits the person. [Apple: Sign in with Apple](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple)
- Signed in: use a leading avatar, name, email, and a quiet authenticated-method label in one row. Remove the gradient banner, floating avatar, large shadow, and decorative verified badge. They create a second visual system and compete with the actual settings hierarchy.
- Use semantic system backgrounds, label colors, SF Symbols, and SwiftUI text styles so Dark Mode, increased contrast, and Dynamic Type adapt automatically. [Apple: Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode), [Apple: Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- Keep authentication controls visible after a recoverable failure. Show a concise inline message such as `Apple sign-in is temporarily unavailable`, with retry or dismiss. Log the HTTP status and JSON for development, but never display transport details as account content. Apple recommends integrating ordinary status feedback into context and reserving alerts for critical, actionable information. [Apple: Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback)

## Sign out

Plain local sign-out is reversible by signing in again and has no data-loss consequence. The simplest native behavior is to sign out immediately from the clearly labeled red row. Apple advises against alerts for common, undoable actions or expected data loss. [Apple: Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), [Apple: Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback)

If the product still requires confirmation, use a centered SwiftUI `alert` with `Cancel` and `Sign out`, not `confirmationDialog`. Apple describes an alert as appropriate for binary confirm or cancel, while a confirmation dialog provides action-sheet choices related to an intentional action and adapts its appearance by device. In a regular iOS size class, SwiftUI renders a confirmation dialog as a popover. A one-action sign-out sheet therefore adds no choice and explains the misplaced anchored presentation in the current UI. [Apple: Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), [Apple: Action sheets](https://developer.apple.com/design/human-interface-guidelines/action-sheets), [Apple: `confirmationDialog`](https://developer.apple.com/documentation/swiftui/view/confirmationdialog%28_%3Aispresented%3Atitlevisibility%3Aactions%3A%29)

Use `confirmationDialog` only if sign-out later has multiple real outcomes, such as `Sign out of this device`, `Sign out everywhere`, and `Cancel`.

## Implementation target

1. Refactor the screen to grouped rows and remove the custom signed-in hero card.
2. Render both provider buttons at full width and 44 pt height with the same 10 to 12 pt continuous corner radius and vertical gap.
3. Use a white Apple button in Dark Mode and a white outlined Apple button in Light Mode. Keep Google on its light scheme beside either one for equal prominence.
4. Build both visible surfaces from the providers' official current artwork. Align their logo columns at the same leading inset and center their labels, but retain Apple's 44/19 proportion and Google's Google Sans Medium 14/20 typography.
5. Keep AuthenticationServices and `GIDSignIn` behind those custom surfaces. Add explicit localized accessibility labels because the custom Apple control no longer inherits them from `SignInWithAppleButton`.
6. Prefer immediate sign-out. If confirmation remains, replace the view-level `confirmationDialog` with a centered binary `alert`.
7. Verify Dark Mode, Light Mode, increased contrast, VoiceOver labels, and at least one accessibility Dynamic Type size on an iPhone.
