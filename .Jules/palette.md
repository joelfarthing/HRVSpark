## 2024-05-28 - Grouping Spaced Views for VoiceOver
**Learning:** When using `HStack` with a `Spacer()` to align text (e.g. Label on the left, Status on the right), VoiceOver reads them as completely separate, unassociated items.
**Action:** Always apply `.accessibilityElement(children: .combine)` to the parent `HStack` so the entire row is read smoothly as a single logical piece of information (e.g. "HealthKit Access, Granted").
