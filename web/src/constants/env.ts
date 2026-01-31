export function getEnvVar(name: string): string {
  const value = import.meta.env[name];
  if (!value) throw new Error(`Missing env variable: ${name}`);
  return value;
}

export function getPackageId(): string {
  return getEnvVar("VITE_PACKAGE_ID");
}

export function getTournamentId(): string {
  return getEnvVar("VITE_TOURNAMENT_ID");
}
