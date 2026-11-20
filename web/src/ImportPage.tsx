import type { User } from 'firebase/auth'
import { useState } from 'react'
import { BackLink, useLoad } from './App'
import { listBeans, saveBeans } from './firebase'
import { mergeImport, parseImport, parseSnapshot } from './model'

export function ImportPage({ user }: { user: User }) {
  const [beans, err, reload] = useLoad(() => listBeans(user.uid), [user.uid])
  const [text, setText] = useState('')
  const [msg, setMsg] = useState<{ ok: boolean; text: string; href?: string } | null>(null)
  const [busy, setBusy] = useState(false)

  const run = async (job: () => Promise<{ text: string; href?: string }>) => {
    setBusy(true); setMsg(null)
    try { setMsg({ ok: true, ...(await job()) }); reload() } catch (e: any) { setMsg({ ok: false, text: `가져오지 못했습니다: ${e.message ?? e}` }) }
    setBusy(false)
  }

  const importText = () => run(async () => {
    const imp = parseImport(text)
    const existing = beans?.find((b) => b.name === imp.bean.name)
    const bean = mergeImport(existing, imp)
    await saveBeans(user.uid, [bean])
    setText('')
    return { text: `${existing ? '갱신' : '추가'}: ${imp.bean.name} (레시피 ${imp.brews.length}개)`, href: `#/m/${user.uid}/b/${bean.id}` }
  })

  const importFile = (file: File) => run(async () => {
    const list = parseSnapshot(await file.text())
    await saveBeans(user.uid, list)
    return { text: `백업에서 원두 ${list.length}개를 올렸습니다 (같은 원두는 덮어씀)`, href: '#/' }
  })

  return (
    <section className="narrow">
      <BackLink href="#/">내 원두</BackLink>
      <h2>가져오기</h2>
      {msg && <p className={`banner ${msg.ok ? 'ok' : 'error'}`}>{msg.text} {msg.ok && msg.href && <a href={msg.href}>보기 ›</a>}</p>}
      {err && <p className="banner error">{err}</p>}

      <div className="card">
        <h3 className="cardtitle">ChatGPT JSON 붙여넣기</h3>
        <p className="muted small">ChatGPT 답변 맨 끝의 📦 JSON 블록을 통째로 붙여넣으세요(코드블록 표시가 섞여도 됩니다). 이미 있는 이름의 원두는 정보와 ★ 기준 레시피가 새것으로 바뀝니다.</p>
        <textarea rows={8} value={text} onChange={(e) => setText(e.target.value)} placeholder='{"bean": {...}, "brews": [...]}' />
        <button className="primary" disabled={busy || !beans || !text.trim()} onClick={importText}>{busy ? '올리는 중…' : '가져오기'}</button>
      </div>

      <div className="card">
        <h3 className="cardtitle">빈무위키 앱 백업 파일 올리기</h3>
        <p className="muted small">앱 › 설정 › 백업 파일 내보내기로 만든 .json. 앱에 있는 원두를 한 번에 옮길 때 씁니다.</p>
        <label className={`button ${busy || !beans ? 'disabled' : ''}`}>
          파일 선택…
          <input type="file" accept="application/json,.json" hidden disabled={busy || !beans}
            onChange={(e) => { const f = e.target.files?.[0]; if (f) importFile(f); e.target.value = '' }} />
        </label>
      </div>
    </section>
  )
}
