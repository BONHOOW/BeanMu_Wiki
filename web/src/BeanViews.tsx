import { useState } from 'react'
import { BackLink, useLive, useTitle } from './App'
import { deleteBean, watchBean } from './firebase'
import {
  type Bean, type Brew, countryText, dripperSiblings, finalRatioText, flowSplit, gramsText, grindParts, memoHtml,
  ratioText, recipeCards, roastColor, roastIndex, timeText,
} from './model'

export function RoastBar({ level }: { level: string }) {
  const i = roastIndex(level)
  if (i < 0) return null
  const filled = Math.round(((i + 1) / 7) * 5)   // 7단계 → 5칸
  return (
    <span className="roast" title={level}>
      {[0, 1, 2, 3, 4].map((k) => <i key={k} style={{ background: k < filled ? roastColor(level) : undefined }} />)}
      <span className="small muted">{level}</span>
    </span>
  )
}

export function BeanDetail({ uid, beanId, own, serving }: { uid: string; beanId: string; own: boolean; serving: string | null }) {
  const [bean, err] = useLive<Bean | null>((next, fail) => watchBean(uid, beanId, next, fail), [uid, beanId])
  useTitle(bean?.name)
  const back = own ? '#/' : `#/m/${uid}`
  const remove = async () => {
    if (!bean || !confirm(`${bean.name}을(를) 삭제할까요? 팀원들에게서도 사라집니다.`)) return
    await deleteBean(uid, bean.id)
    location.hash = back
  }
  if (err) return <p className="error">{err}</p>
  if (bean === undefined) return <p className="muted">불러오는 중…</p>
  if (!bean) return <p className="muted">원두를 찾을 수 없습니다.</p>
  const info: [string, string][] = [
    ['로스터리', bean.roaster], ['원산지', countryText(bean)], ['지역', bean.region], ['농장', bean.farm],
    ['고도', bean.altitude], ['품종', bean.variety], ['가공', bean.process], ['로스팅', bean.roastLevel],
  ]
  return (
    <section>
      <BackLink href={back}>{own ? '내 원두' : '원두 목록'}</BackLink>
      <h2>{bean.name} {bean.isBlend && <span className="pill">블렌드</span>}</h2>
      <p className="muted">{[bean.roaster, countryText(bean)].filter(Boolean).join(' · ')}</p>
      <RoastBar level={bean.roastLevel} />
      {bean.cupNotes.length > 0 && <div className="chips">{bean.cupNotes.map((n) => <span key={n} className="pill">{n}</span>)}</div>}

      <Recipes bean={bean} initial={serving === 'hot' ? false : serving === 'iced' ? true : undefined} />

      {bean.memo && (
        <div className="card">
          <h3 className="cardtitle">메모</h3>
          <div className="memo" dangerouslySetInnerHTML={{ __html: memoHtml(bean.memo) }} />
        </div>
      )}
      <div className="card">
        <h3 className="cardtitle">원산지</h3>
        <dl className="info">
          {info.filter(([, v]) => v).map(([k, v]) => <div key={k}><dt>{k}</dt><dd>{v}</dd></div>)}
          {/^https?:\/\//.test(bean.url) && <div><dt>판매 페이지</dt><dd><a href={bean.url} target="_blank" rel="noreferrer">{new URL(bean.url).host}</a></dd></div>}
        </dl>
      </div>
      {own && (
        <p className="muted small">
          수정은 ChatGPT에서 새 JSON을 받아 홈의 가져오기로 다시 올리면 됩니다 · <button className="link danger" onClick={remove}>이 원두 삭제</button>
        </p>
      )}
    </section>
  )
}

function Recipes({ bean, initial }: { bean: Bean; initial?: boolean }) {
  const servings = ([true, false] as const).filter((iced) => recipeCards(bean, iced).length)
  const [iced, setIced] = useState<boolean>(initial !== undefined && servings.includes(initial as never) ? initial : servings[0] ?? true)
  if (!servings.length) return <p className="muted">레시피가 없습니다.</p>
  const cards = recipeCards(bean, iced)
  return (
    <div className="recipes">
      <div className="tabs">
        {servings.map((s) => (
          <button key={String(s)} className={`tab ${s ? 'iced' : 'hot'} ${s === iced ? 'on' : ''}`} onClick={() => setIced(s)}>
            {s ? 'ICED' : 'HOT'}
          </button>
        ))}
      </div>
      {cards.map((b) => <RecipeCard key={b.uuid} bean={bean} first={b} />)}
    </div>
  )
}

function RecipeCard({ bean, first }: { bean: Bean; first: Brew }) {
  const siblings = dripperSiblings(bean, first)
  const [method, setMethod] = useState(first.method)
  const brew = siblings.find((b) => b.method === method) ?? first
  const [showNotes, setShowNotes] = useState(false)
  const cond: [string, string | null][] = [
    ['원두', brew.doseGrams !== null ? gramsText(brew.doseGrams) : null],
    ['물', brew.waterGrams !== null ? gramsText(brew.waterGrams) : null],
    ['얼음', brew.isIced && brew.iceGrams !== null ? gramsText(brew.iceGrams) : null],
    ['온도', brew.waterTempC !== null ? `${brew.waterTempC}°C` : null],
    ['비율', ratioText(brew.doseGrams, brew.waterGrams)],
    ['최종', brew.isIced ? finalRatioText(brew) : null],
    ['시간', brew.time || null],
  ]
  const last = brew.steps.at(-1)
  return (
    <div className="card recipe">
      {siblings.length > 1 && (
        <div className="seg">
          {siblings.map((s) => (
            <button key={s.uuid} className={s.method === brew.method ? 'on' : ''} onClick={() => setMethod(s.method)}>{s.method}</button>
          ))}
        </div>
      )}
      <div className="head">
        <span className={`badge ${brew.isIced ? 'iced' : 'hot'}`}>{brew.isIced ? 'ICED' : 'HOT'}</span>
        <b>{brew.method}{brew.variant && ` · ${brew.variant}`}</b>
        {brew.isFavorite && <span className="star">★ 기준 레시피</span>}
      </div>
      <dl className="cond">
        {cond.filter(([, v]) => v).map(([k, v]) => <div key={k}><dt>{k}</dt><dd>{v}</dd></div>)}
      </dl>
      {brew.grind && <div className="chips">{grindParts(brew.grind).map((g) => <span key={g} className="pill grind">{g}</span>)}</div>}
      <ol className="steps">
        {brew.steps.map((s, i) => {
          const [flow, rest] = flowSplit(s.note)
          const pour = i === 0 || s.grams > brew.steps[i - 1].grams
          return (
            <li key={i}>
              <span className="t">{timeText(s.atSeconds)}</span>
              <span className={`g ${pour ? '' : 'muted'}`}>{gramsText(s.grams)}</span>
              <span className="n">{flow && <span className="pill flow">{flow}</span>}{rest}</span>
            </li>
          )
        })}
        {last && brew.time && brew.time !== timeText(last.atSeconds) && !/제거|종료/.test(last.note) && (
          <li><span className="t">{brew.time}</span><span className="g muted">{gramsText(last.grams)}</span><span className="n muted">추출 종료</span></li>
        )}
      </ol>
      {brew.notes && (
        <>
          <button className="link" onClick={() => setShowNotes(!showNotes)}>{showNotes ? '노트 접기' : '노트 펼치기'}</button>
          {showNotes && <div className="memo" dangerouslySetInnerHTML={{ __html: memoHtml(brew.notes) }} />}
        </>
      )}
    </div>
  )
}
