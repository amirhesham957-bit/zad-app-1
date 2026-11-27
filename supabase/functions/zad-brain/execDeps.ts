// m4.5 pass 3: what the moved executeTool case bodies still need from index.ts (injected by params, no new globals).
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import type { AuditScope } from "./audit.ts";
import type { Polarity } from "../_shared/dealRelevance.ts";
import type { RunContext } from "./validators.ts";

export interface ToolDeps {
  bumpAffinity: (sb: SupabaseClient, userId: string, polarity: Polarity, term: string, confidence: number) => Promise<void>;
  callCoreIntel: (action: string, payload: unknown, userId: string, timeoutMs?: number) => Promise<any | null>;
  addLinesThroughDoor: (
    sb: SupabaseClient, userId: string, scope: AuditScope, tool: string, input: unknown,
    lines: Array<{ item_name: string; quantity: number }>,
  ) => Promise<{ added: Array<{ id: string | null; item_name: string; quantity: number }>; refusal: string | null }>;
  executeTool: (sb: SupabaseClient, userId: string, name: string, input: any, snap: any, ctx: RunContext, scope: AuditScope) => Promise<string>;
  LOCATION_MAX_AGE_MS: number;
  MAX_SEARCHES_PER_TURN: number;
  HOUSE_SECTIONS_ON_REQUEST: readonly string[];
}
