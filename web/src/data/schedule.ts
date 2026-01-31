import { Match, Phase } from "../types/match";

/**
 * Full 104-match schedule for the 2026 FIFA World Cup.
 *
 * Index layout (must match scoring.move):
 *   0-71   Group stage  (group g = matches g*6 .. g*6+5)
 *   72-87  Round of 32
 *   88-95  Round of 16
 *   96-99  Quarter-Finals
 *   100-101 Semi-Finals
 *   102    Third-place play-off
 *   103    Final
 *
 * Each group of 4 teams (T1, T2, T3, T4) plays 6 matches in round-robin:
 *   MD1: T1vT2, T3vT4
 *   MD2: T1vT3, T2vT4
 *   MD3: T1vT4, T2vT3
 *
 * Group stage dates: Jun 11 -- Jun 28, 2026
 * R32 dates:         Jul 1 -- Jul 4, 2026
 * R16 dates:         Jul 5 -- Jul 6, 2026
 * QF dates:          Jul 9 -- Jul 10, 2026
 * SF dates:          Jul 13 -- Jul 14, 2026
 * 3rd place:         Jul 18, 2026
 * Final:             Jul 19, 2026
 */

// ── Venue key rotation helpers ────────────────────────────────
const V = [
  "metlife", "att", "sofi", "hardrock", "lumen", "gillette",
  "lincoln", "nrg", "mercedes", "levis", "geodis",
  "azteca", "akron", "bbva", "bmo", "bcplace",
] as const;

function venue(matchIndex: number): string {
  return V[matchIndex % V.length];
}

// ── Group definitions (must mirror groups.ts) ─────────────────
const G: string[][] = [
  /* A */ ["USA", "SEN", "UZB", "NZL"],
  /* B */ ["MEX", "ENG", "EGY", "IDN"],
  /* C */ ["CAN", "FRA", "NGA", "QAT"],
  /* D */ ["ARG", "TUR", "CMR", "HON"],
  /* E */ ["BRA", "DEN", "ALG", "KOR"],
  /* F */ ["GER", "URU", "JPN", "RSA"],
  /* G */ ["ESP", "COL", "IRN", "SOL"],
  /* H */ ["POR", "PAR", "AUS", "CIV"],
  /* I */ ["NED", "ECU", "KSA", "PAN"],
  /* J */ ["ITA", "JAM", "IRQ", "UKR"],
  /* K */ ["BEL", "MAR", "AUT", "COD"],
  /* L */ ["CRO", "POL", "SUI", "SRB"],
];

const GROUP_LABELS = "ABCDEFGHIJKL";

// ── Group stage date pool ────────────────────────────────────
// 72 matches over 18 calendar days, 4 matches per day.
// Jun 11 -- Jun 28, 2026
// Kick-off times (UTC): 15:00, 18:00, 21:00, 00:00 (next day)
const groupKickoffs = [
  "15:00:00Z",
  "18:00:00Z",
  "21:00:00Z",
  "00:00:00Z",
];

function groupDate(dayOffset: number, slotIndex: number): string {
  const base = new Date(Date.UTC(2026, 5, 11)); // Jun 11
  const d = new Date(base.getTime() + dayOffset * 86400000);
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}T${groupKickoffs[slotIndex]}`;
}

// ── Build group stage (matches 0-71) ─────────────────────────
// Round-robin order for a group [T1, T2, T3, T4]:
//   Match 0: T1 v T2   (MD1)
//   Match 1: T3 v T4   (MD1)
//   Match 2: T1 v T3   (MD2)
//   Match 3: T2 v T4   (MD2)
//   Match 4: T1 v T4   (MD3)
//   Match 5: T2 v T3   (MD3)
const pairings: [number, number][] = [
  [0, 1], [2, 3], // MD1
  [0, 2], [1, 3], // MD2
  [0, 3], [1, 2], // MD3
];

// Day assignments: 12 groups x 3 match days = 36 group-matchdays
// 2 matches per group-matchday, 4 matches per calendar day => 18 calendar days
// We interleave groups across days for TV scheduling variety.
// Schedule pattern: groups play on days spread across the 18-day window.
// MD1: days 0-5 (groups A-L play MD1 across 6 days, 2 groups/day)
// MD2: days 6-11
// MD3: days 12-17
function groupDayOffset(groupIdx: number, matchDay: number): number {
  // matchDay 0,1,2 => day blocks 0-5, 6-11, 12-17
  const block = matchDay * 6;
  const dayInBlock = Math.floor(groupIdx / 2);
  return block + dayInBlock;
}

function groupSlot(groupIdx: number, matchInDay: number): number {
  // Even-indexed groups get slots 0,1; odd-indexed groups get slots 2,3
  const base = (groupIdx % 2) * 2;
  return base + matchInDay;
}

const groupStage: Match[] = [];

for (let g = 0; g < 12; g++) {
  const [t1, t2, t3, t4] = G[g];
  const groupId = GROUP_LABELS[g];
  const teams = [t1, t2, t3, t4];

  for (let m = 0; m < 6; m++) {
    const matchIndex = g * 6 + m;
    const matchDay = Math.floor(m / 2); // 0, 0, 1, 1, 2, 2
    const matchInDay = m % 2; // 0, 1, 0, 1, 0, 1
    const [hi, ai] = pairings[m];

    groupStage.push({
      matchIndex,
      home: teams[hi],
      away: teams[ai],
      date: groupDate(groupDayOffset(g, matchDay), groupSlot(g, matchInDay)),
      venue: venue(matchIndex),
      phase: Phase.Group,
      group: groupId,
    });
  }
}

// ── Knockout venue assignments ────────────────────────────────
// Bigger stadiums for later rounds
const koVenues = {
  r32: [
    "att", "sofi", "hardrock", "lumen", "gillette", "lincoln",
    "nrg", "mercedes", "levis", "geodis", "azteca", "akron",
    "bbva", "bmo", "bcplace", "metlife",
  ],
  r16: ["metlife", "att", "sofi", "hardrock", "azteca", "nrg", "mercedes", "lumen"],
  qf: ["metlife", "sofi", "att", "hardrock"],
  sf: ["metlife", "sofi"],
  third: "hardrock",
  final: "metlife",
};

// ── Round of 32 (matches 72-87) ───────────────────────────────
// 16 matches over 4 days: Jul 1-4, 4 matches/day
// Bracket: 1A v 2B, 1B v 2A, 1C v 2D, 1D v 2C, ... etc.
// Using standard FIFA-style bracket crossover within group pairs.
// R32 bracket: top 2 per group (24 teams) + 8 best third-placed = 32 teams.
// Labels: "1X" = winner of group X, "2X" = runner-up, "3X" = best third-placed.
const r32: Match[] = [];
const r32Labels: [string, string][] = [
  ["1A", "2B"],
  ["1C", "2D"],
  ["1E", "2F"],
  ["1G", "2H"],
  ["1B", "2A"],
  ["1D", "2C"],
  ["1F", "2E"],
  ["1H", "2G"],
  ["1I", "2J"],
  ["1K", "2L"],
  ["1J", "2I"],
  ["1L", "2K"],
  ["3A", "3D"],
  ["3B", "3E"],
  ["3C", "3F"],
  ["3G", "3J"],
];

for (let i = 0; i < 16; i++) {
  const matchIndex = 72 + i;
  const dayOffset = Math.floor(i / 4); // 0-3
  const slotInDay = i % 4;
  const baseDate = new Date(Date.UTC(2026, 6, 1)); // Jul 1
  const d = new Date(baseDate.getTime() + dayOffset * 86400000);
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  const time = groupKickoffs[slotInDay];

  r32.push({
    matchIndex,
    home: r32Labels[i][0],
    away: r32Labels[i][1],
    date: `${year}-${month}-${day}T${time}`,
    venue: koVenues.r32[i],
    phase: Phase.R32,
  });
}

// ── Round of 16 (matches 88-95) ───────────────────────────────
// 8 matches over 2 days: Jul 5-6, 4 matches/day
const r16Labels: [string, string][] = [
  ["W-M72", "W-M73"],
  ["W-M74", "W-M75"],
  ["W-M76", "W-M77"],
  ["W-M78", "W-M79"],
  ["W-M80", "W-M81"],
  ["W-M82", "W-M83"],
  ["W-M84", "W-M85"],
  ["W-M86", "W-M87"],
];

const r16: Match[] = [];
for (let i = 0; i < 8; i++) {
  const matchIndex = 88 + i;
  const dayOffset = Math.floor(i / 4); // 0-1
  const slotInDay = i % 4;
  const baseDate = new Date(Date.UTC(2026, 6, 5)); // Jul 5
  const d = new Date(baseDate.getTime() + dayOffset * 86400000);
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  const time = groupKickoffs[slotInDay];

  r16.push({
    matchIndex,
    home: r16Labels[i][0],
    away: r16Labels[i][1],
    date: `${year}-${month}-${day}T${time}`,
    venue: koVenues.r16[i],
    phase: Phase.R16,
  });
}

// ── Quarter-Finals (matches 96-99) ────────────────────────────
// 4 matches over 2 days: Jul 9-10, 2 matches/day
const qfLabels: [string, string][] = [
  ["W-M88", "W-M89"],
  ["W-M90", "W-M91"],
  ["W-M92", "W-M93"],
  ["W-M94", "W-M95"],
];

const qf: Match[] = [];
for (let i = 0; i < 4; i++) {
  const matchIndex = 96 + i;
  const dayOffset = Math.floor(i / 2); // 0-1
  const slotInDay = i % 2;
  const baseDate = new Date(Date.UTC(2026, 6, 9)); // Jul 9
  const d = new Date(baseDate.getTime() + dayOffset * 86400000);
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  const times = ["18:00:00Z", "21:00:00Z"];

  qf.push({
    matchIndex,
    home: qfLabels[i][0],
    away: qfLabels[i][1],
    date: `${year}-${month}-${day}T${times[slotInDay]}`,
    venue: koVenues.qf[i],
    phase: Phase.QF,
  });
}

// ── Semi-Finals (matches 100-101) ─────────────────────────────
// 2 matches: Jul 13, Jul 14
const sfLabels: [string, string][] = [
  ["W-M96", "W-M97"],
  ["W-M98", "W-M99"],
];

const sf: Match[] = [];
for (let i = 0; i < 2; i++) {
  const matchIndex = 100 + i;
  const baseDate = new Date(Date.UTC(2026, 6, 13)); // Jul 13
  const d = new Date(baseDate.getTime() + i * 86400000);
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");

  sf.push({
    matchIndex,
    home: sfLabels[i][0],
    away: sfLabels[i][1],
    date: `${year}-${month}-${day}T21:00:00Z`,
    venue: koVenues.sf[i],
    phase: Phase.SF,
  });
}

// ── Third-place play-off (match 102) ──────────────────────────
const thirdPlace: Match = {
  matchIndex: 102,
  home: "L-M100",
  away: "L-M101",
  date: "2026-07-18T21:00:00Z",
  venue: koVenues.third,
  phase: Phase.Third,
};

// ── Final (match 103) ─────────────────────────────────────────
const final_: Match = {
  matchIndex: 103,
  home: "W-M100",
  away: "W-M101",
  date: "2026-07-19T21:00:00Z",
  venue: koVenues.final,
  phase: Phase.Final,
};

// ── Export ─────────────────────────────────────────────────────
export const SCHEDULE: Match[] = [
  ...groupStage,
  ...r32,
  ...r16,
  ...qf,
  ...sf,
  thirdPlace,
  final_,
];

// Sanity check at import time during development
if (SCHEDULE.length !== 104) {
  console.error(
    `[schedule] Expected 104 matches but got ${SCHEDULE.length}`,
  );
}

/** Lookup a single match by its index */
export function getMatch(matchIndex: number): Match | undefined {
  return SCHEDULE.find((m) => m.matchIndex === matchIndex);
}

/** Get all matches for a specific phase */
export function getMatchesByPhase(phase: Phase): Match[] {
  return SCHEDULE.filter((m) => m.phase === phase);
}

/** Get all matches for a specific group */
export function getGroupMatches(groupId: string): Match[] {
  return SCHEDULE.filter((m) => m.group === groupId);
}
