import chrono from 'chrono-node'

export const parseNaturalDate = (input: string, refDate: Date = new Date()): Date | null => {
  const result = chrono.parseDate(input, refDate, { forwardDate: true })
  return result ?? null
}
