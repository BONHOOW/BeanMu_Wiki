import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  canonicalMethod, dripperSiblings, finalRatioText, flowSplit, grindParts, memoHtml, mergeImport,
  parseImport, parseSnapshot, recipeCards, secondsFrom,
} from './model'

const example = readFileSync(new URL('../../docs/import-example.json', import.meta.url), 'utf8')

describe('parseImport', () => {
  it('reads the prompt example: 6 favorites across 3 drippers, 4 grinders', () => {
    const r = parseImport('```json\n' + example + '\n```')   // 코드블록 감싸도 됨
    expect(r.brews).toHaveLength(6)
    expect(r.brews.every((b) => b.isFavorite)).toBe(true)
    expect(new Set(r.brews.map((b) => b.method))).toEqual(new Set(['V60', 'V60 NEO', 'V60 NEO 스위치']))
    for (const b of r.brews) {
      expect(grindParts(b.grind)).toHaveLength(4)
      expect(b.waterGrams).toBe(b.steps.at(-1)!.grams)
      expect(b.iceGrams === null).toBe(!b.isIced)
    }
  })

  it('normalizes legacy and alias input', () => {
    const r = parseImport(JSON.stringify({ bean: { name: 'x', blend: true }, brews: [
      { method: 'V60 ICED', iceGrams: 100, steps: [{ at: '0:30', grams: 40 }, { at: 75, grams: 200 }, { at: 'bad' }] },
      { method: '네오', iceGrams: 100, steps: [] },
    ] }))
    expect(r.bean.isBlend).toBe(true)
    expect(r.brews[0]).toMatchObject({ method: 'V60', isIced: true, iceGrams: 100, waterGrams: 200 })
    expect(r.brews[0].steps.map((s) => s.atSeconds)).toEqual([30, 75])   // grams 없는 단계 제거
    expect(r.brews[1]).toMatchObject({ method: 'V60 NEO', isIced: false, iceGrams: null })
  })

  it('rejects missing name', () => {
    expect(() => parseImport('{"bean":{}}')).toThrow()
    expect(() => parseImport('nothing')).toThrow()
  })
})

describe('mergeImport', () => {
  it('replaces the same slot favorite instead of duplicating', () => {
    const first = mergeImport(undefined, parseImport(example))
    const again = mergeImport(first, parseImport(example))
    expect(again.id).toBe(first.id)
    expect(again.brews).toHaveLength(6)
    const iced = recipeCards(again, true)
    expect(iced).toHaveLength(1)
    expect(dripperSiblings(again, iced[0]).map((b) => b.method)).toEqual(['V60', 'V60 NEO', 'V60 NEO 스위치'])
  })
})

describe('parseSnapshot', () => {
  it('maps app backup records', () => {
    const beans = parseSnapshot(JSON.stringify({ schemaVersion: 1, beans: [{ uuid: 'B1', name: 'n', isBlend: true, brews: [
      { uuid: 'R1', method: 'V60', isIced: true, doseGrams: 20, waterGrams: 180, iceGrams: 120, steps: [{ atSeconds: 0, grams: 40, note: '' }] },
    ] }] }))
    expect(beans[0]).toMatchObject({ id: 'B1', isBlend: true })
    expect(finalRatioText(beans[0].brews[0])).toBe('1:15')
    expect(() => parseSnapshot('{"schemaVersion":2,"beans":[]}')).toThrow()
  })
})

describe('helpers', () => {
  it('splits flow targets out of notes', () => {
    expect(flowSplit('4~5 g/s · 가는 나선형')).toEqual(['4~5 g/s', '가는 나선형'])
    expect(flowSplit('센터 3 g/s')).toEqual(['3 g/s', '센터'])
    expect(flowSplit('밸브 열기')).toEqual([null, '밸브 열기'])
  })
  it('parses times and aliases', () => {
    expect(secondsFrom('1:15')).toBe(75)
    expect(secondsFrom('1:75')).toBeNull()
    expect(canonicalMethod('neo switch')).toBe('V60 NEO 스위치')
    expect(canonicalMethod('Kalita')).toBe('칼리타 101')
  })
  it('renders memo safely without strikethrough', () => {
    expect(memoHtml('**굵게** 3~4 g/s <b>')).toBe('<strong>굵게</strong> 3~4 g/s &lt;b&gt;')
  })
})
