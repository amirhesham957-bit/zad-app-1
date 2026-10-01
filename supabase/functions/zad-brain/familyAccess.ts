// Who may see other family members' spending through the brain.
//
// The same rule as zad_family_digest (20260814213856): admin, parent or owner see
// everyone; anyone else sees only themselves. The brain reads family transactions with
// the service role, which bypasses RLS, so a tool that shows per-member spending has to
// apply this itself — RLS lets a parent read a child's transactions, never the other way.
export function canSeeFamilySpending(role: string | null | undefined): boolean {
  return ["admin", "parent", "owner"].includes(String(role ?? "").trim().toLowerCase());
}

/**
 * Whose spending a family view may show to [viewerId]: theirs, and each member who granted
 * them the `spending` share (zad_family_shares, owner's decision 2026-10-01 — opt-in, the
 * member agrees first). The admin role alone used to be enough.
 */
export function visibleSpenders<T extends { user_id: string }>(
  viewerId: string,
  members: readonly T[],
  grantedOwnerIds: Iterable<string>,
): T[] {
  const granted = new Set(grantedOwnerIds);
  return members.filter((m) => m.user_id === viewerId || granted.has(m.user_id));
}
