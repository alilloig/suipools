export enum Phase {
  Group = 0,
  R32 = 1,
  R16 = 2,
  QF = 3,
  SF = 4,
  Third = 5,
  Final = 6,
}

export interface Team {
  code: string;
  name: string;
  flag: string;
}

export interface Match {
  matchIndex: number;
  home: string; // team code or placeholder like "Winner Group A"
  away: string;
  date: string; // ISO date string
  venue: string; // venue key
  phase: Phase;
  group?: string; // group ID for group stage matches
}

export type GroupId = "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J" | "K" | "L";

export interface Group {
  id: GroupId;
  teams: string[]; // team codes
}

export interface Venue {
  name: string;
  city: string;
  country: string;
}

export interface PhaseInfo {
  phase: Phase;
  label: string;
  matchStart: number; // inclusive
  matchEnd: number; // exclusive
  deadlineIndex: number;
  pointsPerMatch: number;
}
