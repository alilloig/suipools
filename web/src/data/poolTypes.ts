export interface PoolType {
  id: string;
  title: string;
  icon: string;
  tagline: string;
  route: string;
  enabled: boolean;
}

export const POOL_TYPES: PoolType[] = [
  {
    id: "world-cup",
    title: "World Cup 2026",
    icon: "⚽",
    tagline: "Predict every match from groups to the final",
    route: "/world-cup",
    enabled: true,
  },
];
