import { Group, GroupId } from "../types/match";

/**
 * Placeholder groups for the 2026 FIFA World Cup (48 teams, 12 groups of 4).
 *
 * The official draw has not taken place yet. These groups are arranged
 * with realistic seeding in mind:
 *   - Pot 1 (hosts + top seeds) spread across groups
 *   - Geographic diversity within each group
 *   - No two teams from the same confederation in the same group (where possible)
 *
 * Groups will be updated once the official draw is conducted.
 */
export const GROUPS: Record<GroupId, Group> = {
  // ── Group A ─ Host group (USA) ──────────────────────────────
  A: { id: "A", teams: ["USA", "SEN", "UZB", "NZL"] },

  // ── Group B ─ Host group (Mexico) ───────────────────────────
  B: { id: "B", teams: ["MEX", "ENG", "EGY", "IDN"] },

  // ── Group C ─ Host group (Canada) ───────────────────────────
  C: { id: "C", teams: ["CAN", "FRA", "NGA", "QAT"] },

  // ── Group D ─────────────────────────────────────────────────
  D: { id: "D", teams: ["ARG", "TUR", "CMR", "HON"] },

  // ── Group E ─────────────────────────────────────────────────
  E: { id: "E", teams: ["BRA", "DEN", "ALG", "KOR"] },

  // ── Group F ─────────────────────────────────────────────────
  F: { id: "F", teams: ["GER", "URU", "JPN", "RSA"] },

  // ── Group G ─────────────────────────────────────────────────
  G: { id: "G", teams: ["ESP", "COL", "IRN", "SOL"] },

  // ── Group H ─────────────────────────────────────────────────
  H: { id: "H", teams: ["POR", "PAR", "AUS", "CIV"] },

  // ── Group I ─────────────────────────────────────────────────
  I: { id: "I", teams: ["NED", "ECU", "KSA", "PAN"] },

  // ── Group J ─────────────────────────────────────────────────
  J: { id: "J", teams: ["ITA", "JAM", "IRQ", "UKR"] },

  // ── Group K ─────────────────────────────────────────────────
  K: { id: "K", teams: ["BEL", "MAR", "AUT", "COD"] },

  // ── Group L ─────────────────────────────────────────────────
  L: { id: "L", teams: ["CRO", "POL", "SUI", "SRB"] },
};

/** Ordered list of all group IDs */
export const GROUP_IDS: GroupId[] = [
  "A", "B", "C", "D", "E", "F",
  "G", "H", "I", "J", "K", "L",
];
