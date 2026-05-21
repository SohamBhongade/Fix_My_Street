// Single source of truth for issue categories used across the app.
//
// Four things live here on purpose:
//   1. The canonical category list — kept in priority/severity order so it
//      matches the order shown in the manual dropdown and the order the AI
//      sees in its system prompt.
//   2. The canonical category → severity map. This is the authoritative
//      severity for every category; the AI's freeform severity guess is
//      reconciled against this map before persistence so the three
//      low-risk categories below ALWAYS land at severity ≤ 3.
//   3. The volunteer-allowed subset — the three low-risk categories that
//      both residents AND admins can self-assign without municipal
//      involvement (since their canonical severity is ≤ 3, Rule A's
//      admin guardrail at severity > 3 lets admins through too).
//   4. Lookup helpers.
//
// Keep this file dependency-free so it can be imported from anywhere
// (services, screens, future server code) without pulling Flutter widgets.

/// The fifteen canonical categories the AI is allowed to return.
const List<String> kIssueCategories = [
  'Exposed Wiring',
  'Broken Pipelines',
  'Potholes',
  'Traffic Signal Malfunction',
  'Broken Guardrails',
  'Broken Street Lights',
  'Water Accumulation',
  'Cracked Sidewalks',
  'Illegal Dumping',
  'Overflowing Bins',
  'Overgrown Vegetation',
  'Broken Signs',
  'Faded Road Markings',
  'Litter Accumulation',
  'Graffiti',
];

/// Fallback when the AI cannot confidently match a photo to one of the
/// canonical categories. The UI surfaces a manual dropdown in this case.
const String kOtherCategory = 'Other';

/// Canonical severity for every category. This is the source of truth —
/// the AI's freeform severity guess is reconciled against this map by
/// [normalizeSeverityFor] before any report is persisted, so the three
/// low-risk categories (Litter Accumulation, Overgrown Vegetation,
/// Graffiti) ALWAYS land at severity ≤ 3 regardless of what the model
/// returned.
const Map<String, int> kCanonicalCategorySeverity = {
  'Exposed Wiring': 10,
  'Broken Pipelines': 10,
  'Potholes': 8,
  'Traffic Signal Malfunction': 8,
  'Broken Guardrails': 7,
  'Broken Street Lights': 6,
  'Water Accumulation': 5,
  'Cracked Sidewalks': 5,
  'Illegal Dumping': 5,
  'Overflowing Bins': 4,
  // Low-risk trio — pinned to ≤ 3 so both residents and admins can
  // volunteer for them (Rule A's admin cap is severity > 3).
  'Graffiti': 3,
  'Overgrown Vegetation': 2,
  'Litter Accumulation': 1,
  // Other municipal categories that happen to be ≤ 3.
  'Broken Signs': 3,
  'Faded Road Markings': 3,
};

/// The three low-risk categories that BOTH residents and admins can
/// volunteer to fix. Pinned at severity ≤ 3 in [kCanonicalCategorySeverity]
/// so they pass Rule A's admin guardrail.
const Set<String> kVolunteerAllowedCategories = {
  'Litter Accumulation',
  'Overgrown Vegetation',
  'Graffiti',
};

/// `true` when the given category is on the resident+admin volunteer
/// allowlist. Case-sensitive on purpose — the AI is constrained to
/// return exact strings from [kIssueCategories], so any mismatch
/// indicates dirty data we'd rather surface than silently accept.
bool isVolunteeringAllowed(String category) =>
    kVolunteerAllowedCategories.contains(category);

/// Reconciles an arbitrary [severity] against the canonical map.
///
/// Behavior:
///   • If [category] is in [kCanonicalCategorySeverity], returns the
///     canonical value — overriding whatever was passed. This guarantees
///     Litter Accumulation / Overgrown Vegetation / Graffiti always
///     persist at 1 / 2 / 3 respectively.
///   • Otherwise (unknown category, `kOtherCategory`, AI hallucination),
///     clamps the provided value into the valid 1–10 range and returns it.
int normalizeSeverityFor(String category, int severity) {
  final canonical = kCanonicalCategorySeverity[category];
  if (canonical != null) return canonical;
  if (severity < 1) return 1;
  if (severity > 10) return 10;
  return severity;
}
