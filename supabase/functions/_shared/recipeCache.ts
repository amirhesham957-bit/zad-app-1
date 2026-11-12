// The meal_suggestions cache key, in one place, because two actions have to agree on it.
//
// meal_suggestions writes under "meal_suggestions:v2:<user>:…" and rate_recipe deletes
// that user's rows so a dish just disliked stops coming back. The two were written
// separately and drifted: the key gained a "v2:" and the delete kept matching
// "meal_suggestions:<user>:%", which matches nothing. A dislike then did nothing for up
// to AI_CACHE_TTL_MS (6 h) — the same recipe kept arriving from cache.

const PREFIX = "meal_suggestions:v2:";

/** The cache key for one user's suggestions over one pantry. */
export function mealSuggestionsCacheKey(parts: {
  userId: string;
  dialect: string;
  person: string;
  brokeMode: boolean;
  items: string;
}): string {
  return PREFIX + parts.userId + ":" + parts.dialect + ":" + parts.person + ":" +
    (parts.brokeMode ? "broke:" : "") + parts.items;
}

/** A LIKE pattern for every key [mealSuggestionsCacheKey] writes for [userId]. */
export function mealSuggestionsCachePattern(userId: string): string {
  return PREFIX + userId + ":%";
}
