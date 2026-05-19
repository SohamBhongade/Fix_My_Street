// Single source of truth for issue categories used across the app.
//
// Three things live here on purpose:
//   1. The canonical category list — kept in priority/severity order so it
//      matches the order shown in the manual dropdown and the order the AI
//      sees in its system prompt.
//   2. The volunteer-allowed subset — the four low-risk categories a
//      resident can self-assign without municipal involvement.
//   3. The `isVolunteeringAllowed` helper for UI gating.
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

/// The four low-risk categories a resident can volunteer to fix. Anything
/// outside this set must be handled by RAK municipal teams.
const Set<String> kVolunteerAllowedCategories = {
  'Illegal Dumping',
  'Overgrown Vegetation',
  'Graffiti',
  'Litter Accumulation',
};

/// `true` when the given category is safe for a resident to self-volunteer
/// (no specialized tools, no electrical/structural risk). Case-sensitive on
/// purpose — the AI is constrained to return exact strings from
/// [kIssueCategories], so any mismatch indicates dirty data we'd rather
/// surface than silently accept.
bool isVolunteeringAllowed(String category) =>
    kVolunteerAllowedCategories.contains(category);
