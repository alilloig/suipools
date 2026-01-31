import { Venue } from "../types/match";

/**
 * All 16 stadiums for the 2026 FIFA World Cup.
 *   USA: 11 stadiums
 *   Mexico: 3 stadiums
 *   Canada: 2 stadiums
 */
export const VENUES: Record<string, Venue> = {
  // ── United States (11) ──────────────────────────────────────
  metlife: {
    name: "MetLife Stadium",
    city: "East Rutherford, NJ",
    country: "USA",
  },
  att: {
    name: "AT&T Stadium",
    city: "Arlington, TX",
    country: "USA",
  },
  sofi: {
    name: "SoFi Stadium",
    city: "Inglewood, CA",
    country: "USA",
  },
  hardrock: {
    name: "Hard Rock Stadium",
    city: "Miami Gardens, FL",
    country: "USA",
  },
  lumen: {
    name: "Lumen Field",
    city: "Seattle, WA",
    country: "USA",
  },
  gillette: {
    name: "Gillette Stadium",
    city: "Foxborough, MA",
    country: "USA",
  },
  lincoln: {
    name: "Lincoln Financial Field",
    city: "Philadelphia, PA",
    country: "USA",
  },
  nrg: {
    name: "NRG Stadium",
    city: "Houston, TX",
    country: "USA",
  },
  mercedes: {
    name: "Mercedes-Benz Stadium",
    city: "Atlanta, GA",
    country: "USA",
  },
  levis: {
    name: "Levi's Stadium",
    city: "Santa Clara, CA",
    country: "USA",
  },
  geodis: {
    name: "GEODIS Park",
    city: "Nashville, TN",
    country: "USA",
  },

  // ── Mexico (3) ──────────────────────────────────────────────
  azteca: {
    name: "Estadio Azteca",
    city: "Mexico City",
    country: "Mexico",
  },
  akron: {
    name: "Estadio Akron",
    city: "Guadalajara",
    country: "Mexico",
  },
  bbva: {
    name: "Estadio BBVA",
    city: "Monterrey",
    country: "Mexico",
  },

  // ── Canada (2) ──────────────────────────────────────────────
  bmo: {
    name: "BMO Field",
    city: "Toronto",
    country: "Canada",
  },
  bcplace: {
    name: "BC Place",
    city: "Vancouver",
    country: "Canada",
  },
};

/** Ordered list of venue keys for round-robin assignment */
export const VENUE_KEYS = Object.keys(VENUES);
