import { describe, expect, it } from 'vitest'
import { formatMs } from './format'

describe('formatMs', () => {
  it('arrondit à la milliseconde', () => {
    expect(formatMs(12.4)).toBe('12 ms')
  })

  it('affiche un tiret quand la valeur manque', () => {
    expect(formatMs(Number.NaN)).toBe('—')
  })
})
