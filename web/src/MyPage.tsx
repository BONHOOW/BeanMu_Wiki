import type { User } from 'firebase/auth'
import { useState } from 'react'
import { useLoad } from './App'
import { RoastBar } from './BeanViews'
import { deleteBean, listBeans, saveBeans } from './firebase'
import { mergeImport, parseImport, parseSnapshot } from './model'

export function MyPage({ user }: { user: User }) {
  const [beans, err, reload] = useLoad(() => listBeans(user.uid), [user.uid])
  const [text, setText] = useState('')
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null)
  const [busy, setBusy] = useState(false)

  const run = async (job: () => Promise<string>) => {
    setBusy(true); setMsg(null)
    try { setMsg({ ok: true, text: await job() }); reload() } catch (e: any) { setMsg({ ok: false, text: String(e.message ?? e) }) }
    setBusy(false)
  }

  const importText = () => run(async () => {
    const imp = parseImport(text)
    const existing = beans?.find((b) => b.name === imp.bean.name)
    await saveBeans(user.uid, [mergeImport(existing, imp)])
    setText('')
    return `${existing ? '갱신' : '추가'}: ${imp.bean.name} (레시피 ${imp.brews.length}개)`
  })

  const importFile = (file: File) => run(async () => {
    const list = parseSnapshot(await file.text())
    await saveBeans(user.uid, list)
    return `백업에서 원두 ${list.length}개를 올렸습니다 (같은 원두는 덮어씀)`
  })

  return (
    <section>
      <h2>내 레시피</h2>

      <div className="card">
        <h3 className="cardtitle">ChatGPT JSON 가져오기</h3>
        <p className="muted small">ChatGPT 답변 맨 끝의 📦 JSON 블록을 통째로 붙여넣으세요. 같은 이름의 원두는 정보와 ★ 레시피가 교체됩니다.</p>
        <textarea rows={8} value={text} onChange={(e) => setText(e.target.value)} placeholder='{"bean": {...}, "brews": [...]}' />
        <button className="primary" disabled={busy || !beans || !text.trim()} onClick={importText}>가져오기</button>
      </div>

      <div className="card">
        <h3 className="cardtitle">앱 백업 파일 올리기</h3>
        <p className="muted small">빈무위키 앱 › 설정 › 백업 파일 내보내기로 만든 .json. 원두를 한 번에 옮길 때 씁니다.</p>
        <input type="file" accept="application/json,.json" disabled={busy || !beans}
          onChange={(e) => { const f = e.target.files?.[0]; if (f) importFile(f); e.target.value = '' }} />
      </div>

      {msg && <p className={msg.ok ? 'ok' : 'error'}>{msg.text}</p>}
      {err && <p className="error">{err}</p>}

      <h3 className="section">올린 원두 {beans?.length ?? ''}</h3>
      <div className="list">
        {beans?.sort((a, b) => a.name.localeCompare(b.name, 'ko')).map((b) => (
          <div className="row" key={b.id}>
            <a className="grow" href={`#/m/${user.uid}/b/${b.id}`}><b>{b.name}</b><span className="muted small block">{b.roaster}</span></a>
            <RoastBar level={b.roastLevel} />
            <button className="link danger" disabled={busy}
              onClick={() => confirm(`${b.name}을(를) 삭제할까요?`) && run(async () => { await deleteBean(user.uid, b.id); return `삭제: ${b.name}` })}>삭제</button>
          </div>
        ))}
      </div>
    </section>
  )
}
