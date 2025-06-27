import { describe, expect, test } from 'bun:test'
import { parseNaturalDate } from '../../utils/parseNaturalDate'

describe('parseNaturalDate', () => {
  test('tomorrow', () => {
    const now = new Date('2025-06-27T12:00:00Z')
    const result = parseNaturalDate('tomorrow', now)!
    expect(result.getUTCDate()).toBe(28)
  })

  test('next Mon', () => {
    const now = new Date('2025-06-27T12:00:00Z')
    const result = parseNaturalDate('next Mon', now)!
    expect(result.getUTCDay()).toBe(1)
  })

  test('in 48 hours', () => {
    const now = new Date('2025-06-27T12:00:00Z')
    const result = parseNaturalDate('in 48 hours', now)!
    expect(+result - +now).toBe(48 * 3600 * 1000)
  })

  test('29 Jun 2025 14:15', () => {
    const result = parseNaturalDate('29 Jun 2025 14:15', new Date('2025-06-27T00:00:00Z'))!
    expect(result.toISOString()).toBe('2025-06-29T14:15:00.000Z')
  })
})
