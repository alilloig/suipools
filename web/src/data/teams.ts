import { Team } from "../types/match";

/**
 * All 48 teams qualified for the 2026 FIFA World Cup.
 * Keyed by FIFA country code.
 *
 * Distribution:
 *   Africa (9), Asia (9), Europe (16), North America (6),
 *   South America (6), Oceania (2)
 */
export const TEAMS: Record<string, Team> = {
  // ── Africa (9) ──────────────────────────────────────────────
  MAR: { code: "MAR", name: "Morocco", flag: "\u{1F1F2}\u{1F1E6}" },
  SEN: { code: "SEN", name: "Senegal", flag: "\u{1F1F8}\u{1F1F3}" },
  EGY: { code: "EGY", name: "Egypt", flag: "\u{1F1EA}\u{1F1EC}" },
  NGA: { code: "NGA", name: "Nigeria", flag: "\u{1F1F3}\u{1F1EC}" },
  CMR: { code: "CMR", name: "Cameroon", flag: "\u{1F1E8}\u{1F1F2}" },
  ALG: { code: "ALG", name: "Algeria", flag: "\u{1F1E9}\u{1F1FF}" },
  RSA: { code: "RSA", name: "South Africa", flag: "\u{1F1FF}\u{1F1E6}" },
  COD: { code: "COD", name: "DR Congo", flag: "\u{1F1E8}\u{1F1E9}" },
  CIV: { code: "CIV", name: "Ivory Coast", flag: "\u{1F1E8}\u{1F1EE}" },

  // ── Asia (9) ────────────────────────────────────────────────
  JPN: { code: "JPN", name: "Japan", flag: "\u{1F1EF}\u{1F1F5}" },
  KOR: { code: "KOR", name: "South Korea", flag: "\u{1F1F0}\u{1F1F7}" },
  AUS: { code: "AUS", name: "Australia", flag: "\u{1F1E6}\u{1F1FA}" },
  KSA: { code: "KSA", name: "Saudi Arabia", flag: "\u{1F1F8}\u{1F1E6}" },
  IRN: { code: "IRN", name: "Iran", flag: "\u{1F1EE}\u{1F1F7}" },
  IRQ: { code: "IRQ", name: "Iraq", flag: "\u{1F1EE}\u{1F1F6}" },
  QAT: { code: "QAT", name: "Qatar", flag: "\u{1F1F6}\u{1F1E6}" },
  UZB: { code: "UZB", name: "Uzbekistan", flag: "\u{1F1FA}\u{1F1FF}" },
  IDN: { code: "IDN", name: "Indonesia", flag: "\u{1F1EE}\u{1F1E9}" },

  // ── Europe (16) ─────────────────────────────────────────────
  GER: { code: "GER", name: "Germany", flag: "\u{1F1E9}\u{1F1EA}" },
  ESP: { code: "ESP", name: "Spain", flag: "\u{1F1EA}\u{1F1F8}" },
  FRA: { code: "FRA", name: "France", flag: "\u{1F1EB}\u{1F1F7}" },
  ENG: { code: "ENG", name: "England", flag: "\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}" },
  POR: { code: "POR", name: "Portugal", flag: "\u{1F1F5}\u{1F1F9}" },
  NED: { code: "NED", name: "Netherlands", flag: "\u{1F1F3}\u{1F1F1}" },
  BEL: { code: "BEL", name: "Belgium", flag: "\u{1F1E7}\u{1F1EA}" },
  CRO: { code: "CRO", name: "Croatia", flag: "\u{1F1ED}\u{1F1F7}" },
  DEN: { code: "DEN", name: "Denmark", flag: "\u{1F1E9}\u{1F1F0}" },
  SUI: { code: "SUI", name: "Switzerland", flag: "\u{1F1E8}\u{1F1ED}" },
  AUT: { code: "AUT", name: "Austria", flag: "\u{1F1E6}\u{1F1F9}" },
  ITA: { code: "ITA", name: "Italy", flag: "\u{1F1EE}\u{1F1F9}" },
  SRB: { code: "SRB", name: "Serbia", flag: "\u{1F1F7}\u{1F1F8}" },
  UKR: { code: "UKR", name: "Ukraine", flag: "\u{1F1FA}\u{1F1E6}" },
  TUR: { code: "TUR", name: "Turkey", flag: "\u{1F1F9}\u{1F1F7}" },
  POL: { code: "POL", name: "Poland", flag: "\u{1F1F5}\u{1F1F1}" },

  // ── North America (6) ───────────────────────────────────────
  USA: { code: "USA", name: "United States", flag: "\u{1F1FA}\u{1F1F8}" },
  MEX: { code: "MEX", name: "Mexico", flag: "\u{1F1F2}\u{1F1FD}" },
  CAN: { code: "CAN", name: "Canada", flag: "\u{1F1E8}\u{1F1E6}" },
  JAM: { code: "JAM", name: "Jamaica", flag: "\u{1F1EF}\u{1F1F2}" },
  HON: { code: "HON", name: "Honduras", flag: "\u{1F1ED}\u{1F1F3}" },
  PAN: { code: "PAN", name: "Panama", flag: "\u{1F1F5}\u{1F1E6}" },

  // ── South America (6) ──────────────────────────────────────
  ARG: { code: "ARG", name: "Argentina", flag: "\u{1F1E6}\u{1F1F7}" },
  BRA: { code: "BRA", name: "Brazil", flag: "\u{1F1E7}\u{1F1F7}" },
  URU: { code: "URU", name: "Uruguay", flag: "\u{1F1FA}\u{1F1FE}" },
  COL: { code: "COL", name: "Colombia", flag: "\u{1F1E8}\u{1F1F4}" },
  ECU: { code: "ECU", name: "Ecuador", flag: "\u{1F1EA}\u{1F1E8}" },
  PAR: { code: "PAR", name: "Paraguay", flag: "\u{1F1F5}\u{1F1FE}" },

  // ── Oceania (2) ─────────────────────────────────────────────
  NZL: { code: "NZL", name: "New Zealand", flag: "\u{1F1F3}\u{1F1FF}" },
  SOL: { code: "SOL", name: "Solomon Islands", flag: "\u{1F1F8}\u{1F1E7}" },
};

/** Helper: get a team by code, with fallback for knockout placeholders */
export function getTeam(code: string): Team {
  return (
    TEAMS[code] ?? {
      code,
      name: code,
      flag: "\u{1F3F3}\u{FE0F}",
    }
  );
}
