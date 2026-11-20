import type { User } from 'firebase/auth'
import { useEffect, useRef, useState } from 'react'
import { saveBeans } from './firebase'
import { type Bean, mergeImport, parseImport, parseSnapshot } from './model'

export interface ImportResult { text: string; href?: string }

/** 홈의 "+ 가져오기"로 여는 창. ChatGPT JSON 붙여넣기 / 앱 백업 파일 두 탭 */
export function ImportDialog({ user, beans, onClose, onDone }: {
  user: User; beans: Bean[]; onClose: () => void; onDone: (r: ImportResult) => void
}) {
  const ref = useRef<HTMLDialogElement>(null)
  const [tab, setTab] = useState<'json' | 'file'>('json')
  const [text, setText] = useState('')
  const [err, setErr] = useState('')
  const [busy, setBusy] = useState(false)

  useEffect(() => { ref.current?.showModal() }, [])

  const run = async (job: () => Promise<ImportResult>) => {
    setBusy(true); setErr('')
    try { onDone(await job()) } catch (e: any) { setErr(`가져오지 못했습니다: ${e.message ?? e}`) }
    setBusy(false)
  }

  const importText = () => run(async () => {
    const imp = parseImport(text)
    const existing = beans.find((b) => b.name === imp.bean.name)
    const bean = mergeImport(existing, imp)
    await saveBeans(user.uid, [bean])
    return { text: `${existing ? '갱신' : '추가'}: ${imp.bean.name} (레시피 ${imp.brews.length}개)`, href: `#/m/${user.uid}/b/${bean.id}` }
  })

  const importFile = (file: File) => run(async () => {
    const list = parseSnapshot(await file.text())
    await saveBeans(user.uid, list)
    return { text: `앱 백업에서 원두 ${list.length}개를 올렸습니다 (같은 원두는 덮어씀)` }
  })

  return (
    <dialog ref={ref} className="sheet" onClose={onClose} onClick={(e) => e.target === ref.current && !busy && ref.current?.close()}>
      <div className="sheet-body">
        <div className="titlebar">
          <h2>가져오기</h2>
          <button className="link" onClick={() => ref.current?.close()} disabled={busy} aria-label="닫기">닫기</button>
        </div>
        <div className="seg">
          <button className={tab === 'json' ? 'on' : ''} onClick={() => setTab('json')}>ChatGPT JSON</button>
          <button className={tab === 'file' ? 'on' : ''} onClick={() => setTab('file')}>앱 백업 파일</button>
        </div>

        {tab === 'json' ? (
          <>
            <p className="muted small">ChatGPT 답변 맨 끝의 📦 JSON 블록을 통째로 붙여넣으세요(코드블록 표시가 섞여도 됩니다). 이미 있는 이름의 원두는 정보와 ★ 기준 레시피가 새것으로 바뀝니다.</p>
            <textarea rows={9} value={text} autoFocus onChange={(e) => setText(e.target.value)} placeholder='{"bean": {...}, "brews": [...]}' />
            <button className="primary" disabled={busy || !text.trim()} onClick={importText}>{busy ? '올리는 중…' : '가져오기'}</button>
          </>
        ) : (
          <>
            <p className="muted small">빈무위키 앱 › 설정 › 백업 파일 내보내기로 만든 .json. 앱에 있는 원두를 한 번에 옮길 때 씁니다.</p>
            <label className={`button primary ${busy ? 'disabled' : ''}`}>
              {busy ? '올리는 중…' : '파일 선택…'}
              <input type="file" accept="application/json,.json" hidden disabled={busy}
                onChange={(e) => { const f = e.target.files?.[0]; if (f) importFile(f); e.target.value = '' }} />
            </label>
          </>
        )}
        {err && <p className="error">{err}</p>}
      </div>
    </dialog>
  )
}
