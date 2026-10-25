import { describe, expect, it } from 'vitest'

const { draftProblem, draftsFrom, flightBody, flyerPrefill, routeOf } = await import('../src/lib/ticketDrafts')

const leg = (code: string, date: string, from: string, to: string, dep: string, arr: string) => ({
  source: 'ticket', code, date, fromIata: from, fromCity: from, toIata: to, toCity: to, depTime: dep, arrTime: arr,
})

const imported = {
  ticket: { agency: 'DESH TRAVELER', passenger: 'KHAN / MD ARIF HOSSAIN SD', pnr: 'TEST01', ticketNumber: '781-0000000001', issuedOn: '2026-10-24' },
  flyerMatches: [{ name: 'KHAN Arif Hossain', score: 1 }],
  journeys: [
    { direction: 'to_bangladesh' as const, date: '2026-11-13', legs: [leg('MU5842', '2026-11-13', 'TFU', 'KMG', '21:00', '22:30'), leg('MU2035', '2026-11-14', 'KMG', 'DAC', '12:10', '13:00')] },
    { direction: 'from_bangladesh' as const, date: '2026-11-23', legs: [leg('MU2036', '2026-11-23', 'DAC', 'KMG', '14:00', '18:20')] },
  ],
}

describe('ticket drafts', () => {
  it('builds one editable draft per journey with default capacity', () => {
    const drafts = draftsFrom(imported)
    expect(drafts).toHaveLength(2)
    expect(drafts[0]).toMatchObject({ direction: 'to_bangladesh', spaceKg: '44', mobiles: '2', laptops: '1', saved: false })
    expect(routeOf(drafts[0]!.legs)).toBe('TFU → KMG → DAC')
    expect(new Set(drafts.flatMap((d) => [d.key, ...d.legs.map((l) => l.key)])).size).toBe(5)
  })

  it('sends each draft as a ticket-sourced connection flight for the chosen flyer', () => {
    const [outbound] = draftsFrom(imported)
    outbound!.actualCost = '42000'
    outbound!.agencyShare = '8000'
    expect(flightBody(outbound!, 'KHAN Arif Hossain')).toEqual({
      code: 'MU5842+MU2035',
      date: '2026-11-13',
      depTime: '21:00',
      arrTime: '13:00',
      flyerNames: ['KHAN Arif Hossain'],
      actualCost: 42000,
      agencyShare: 8000,
      spaceKg: 44,
      mobiles: 2,
      laptops: 1,
      legs: [
        { source: 'ticket', code: 'MU5842', date: '2026-11-13', fromIata: 'TFU', fromCity: 'TFU', toIata: 'KMG', toCity: 'KMG', depTime: '21:00', arrTime: '22:30' },
        { source: 'ticket', code: 'MU2035', date: '2026-11-14', fromIata: 'KMG', fromCity: 'KMG', toIata: 'DAC', toCity: 'DAC', depTime: '12:10', arrTime: '13:00' },
      ],
    })
  })

  it('names the first edit a draft still needs', () => {
    const [draft] = draftsFrom(imported)
    expect(draftProblem(draft!)).toBe('')
    expect(draftProblem({ ...draft!, legs: [{ ...draft!.legs[0]!, toIata: '' }] })).toMatch(/airport codes/)
    expect(draftProblem({ ...draft!, legs: [{ ...draft!.legs[0]!, depTime: '—' }] })).toMatch(/times/)
    expect(draftProblem({ ...draft!, actualCost: '100', agencyShare: '200' })).toMatch(/cannot exceed/)
    expect(draftProblem({ ...draft!, legs: [] })).toMatch(/at least one/)
  })

  it('turns the ticket name into first-name-first flyer form text', () => {
    expect(flyerPrefill('KHAN / MD ARIF HOSSAIN SD')).toBe('Arif Hossain Khan')
    expect(flyerPrefill(null)).toBeUndefined()
  })
})
