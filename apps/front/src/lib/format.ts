/** Affiche une durée en millisecondes ; une valeur manquante (NaN) devient un tiret. */
export function formatMs(ms: number): string {
  if (Number.isNaN(ms)) return '—'
  return `${Math.round(ms)} ms`
}
