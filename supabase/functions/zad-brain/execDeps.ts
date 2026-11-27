// m4.5 pass 3: what the moved executeTool case bodies still need from index.ts (injected by params, no new globals).
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import type { Polarity } from "../_shared/dealRelevance.ts";
import type { RunContext } from "./validators.ts";
import type { ScheduledLike } from "./scheduleGuard.ts";
import type { MemoryEntity } from "./shared.ts";
import type { SensitiveTopic } from "./sensitiveMemory.ts";

export interface ToolDeps {
  bumpAffinity: (sb: SupabaseClient, userId: string, polarity: Polarity, term: string, confidence: number) => Promise<void>;
  callCoreIntel: (action: string, payload: unknown, userId: string, timeoutMs?: number) => Promise<any | null>;
  addLinesThroughDoor: (
    sb: SupabaseClient, userId: string, scope: AuditScope, tool: string, input: unknown,
    lines: Array<{ item_name: string; quantity: number }>,
  ) => Promise<{ added: Array<{ id: string | null; item_name: string; quantity: number }>; refusal: string | null }>;
  executeTool: (sb: SupabaseClient, userId: string, name: string, input: any, snap: any, ctx: RunContext, scope: AuditScope) => Promise<string>;
  clashCandidates: (sb: SupabaseClient, userId: string, startsAt: string) => Promise<ScheduledLike[]>;
  appointmentMemory: (sb: SupabaseClient, userId: string, parts: unknown[]) => Promise<string>;
  attachEntities: (sb: SupabaseClient, userId: string, noteId: string, about: MemoryEntity[]) => Promise<void>;
  embedAndLinkNote: (
    sb: SupabaseClient, userId: string, scope: string, note: string,
    opts?: { link: boolean; noteId?: string | null },
  ) => Promise<void>;
  householdName: (sb: SupabaseClient, userId: string, name: string) => Promise<string>;
  liveNoteId: (sb: SupabaseClient, userId: string, scope: string, note: string) => Promise<string | null>;
  tickBoughtLine: (
    sb: SupabaseClient, userId: string, familyId: string | null, itemName: string, scope: AuditScope,
  ) => Promise<string | null>;
  writeMemoryNoteWithLinking: (
    sb: SupabaseClient, userId: string, scope: string, note: string, confidence: number,
    familyId?: string | null,
    time?: { validUntil?: string | null; about?: MemoryEntity[]; confirmed?: boolean },
  ) => Promise<
    | { status: "inserted" | "strengthened" | "conflict" | "expired" }
    | { status: "sensitive"; topic: SensitiveTopic }
    | { status: "error"; message: string }
  >;
  writeSingleCopyMemory: (
    sb: SupabaseClient, userId: string, scope: string, note: string, confidence: number,
  ) => Promise<{ error: unknown }>;
  LOCATION_MAX_AGE_MS: number;
  MAX_SEARCHES_PER_TURN: number;
  HOUSE_SECTIONS_ON_REQUEST: readonly string[];
}
