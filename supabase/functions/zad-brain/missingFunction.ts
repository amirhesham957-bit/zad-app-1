/** PostgREST بيرد PGRST202 لما الدالة مش موجودة، وPostgres بيرد 42883. */
export function isMissingFunction(error: { code?: string } | null | undefined): boolean {
  return error?.code === "PGRST202" || error?.code === "42883";
}
