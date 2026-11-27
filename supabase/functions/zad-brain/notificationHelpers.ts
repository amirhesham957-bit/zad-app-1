export function normalizeClientClassification(raw: unknown): "completed" | "failed_or_pending" | "informational" | "ambiguous" {
  const value = String(raw ?? "").toLowerCase();
  if (value === "completed_transaction") return "completed";
  if (value === "failed_or_pending_transaction") return "failed_or_pending";
  if (value === "informational_only") return "informational";
  return "ambiguous";
}

export async function sha256Hex(text: string): Promise<string> {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
