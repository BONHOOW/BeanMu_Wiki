// firestore.rules 검증 — `npm run test:rules` (Firestore 에뮬레이터 필요, Java 11+)
import { assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment } from '@firebase/rules-unit-testing'
import { readFileSync } from 'node:fs'
import { deleteDoc, doc, getDoc, setDoc } from 'firebase/firestore'
import { afterAll, beforeAll, describe, it } from 'vitest'

let env: RulesTestEnvironment
const as = (uid: string, email: string) => env.authenticatedContext(uid, { email, email_verified: true }).firestore()

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-beanmuwiki',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 },
  })
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore()
    await setDoc(doc(db, 'allowlist/friend@gmail.com'), {})
    await setDoc(doc(db, 'members/admin/beans/b1'), { name: 'x' })
  })
})
afterAll(() => env.cleanup())

describe('firestore.rules', () => {
  const admin = () => as('admin', 'gkh30878@gmail.com')
  const friend = () => as('friend', 'friend@gmail.com')
  const stranger = () => as('stranger', 'stranger@gmail.com')

  it('invited users read everyone, strangers read nothing', async () => {
    await assertSucceeds(getDoc(doc(friend(), 'members/admin/beans/b1')))
    await assertFails(getDoc(doc(stranger(), 'members/admin/beans/b1')))
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'members/admin/beans/b1')))
  })
  it('writes only to own subtree', async () => {
    await assertSucceeds(setDoc(doc(friend(), 'members/friend/beans/b2'), { name: 'mine' }))
    await assertFails(setDoc(doc(friend(), 'members/admin/beans/b1'), { name: 'hack' }))
    await assertFails(deleteDoc(doc(friend(), 'members/admin/beans/b1')))
    await assertFails(setDoc(doc(stranger(), 'members/stranger'), { name: 's' }))
  })
  it('allowlist: admin writes, users read only their own entry', async () => {
    await assertSucceeds(setDoc(doc(admin(), 'allowlist/new@gmail.com'), {}))
    await assertFails(setDoc(doc(friend(), 'allowlist/me2@gmail.com'), {}))
    await assertSucceeds(getDoc(doc(friend(), 'allowlist/friend@gmail.com')))
    await assertFails(getDoc(doc(friend(), 'allowlist/new@gmail.com')))
    await assertFails(getDoc(doc(stranger(), "allowlist/friend@gmail.com")))
  })
  it('unverified email is not admin', async () => {
    const fake = env.authenticatedContext('fake', { email: 'gkh30878@gmail.com', email_verified: false }).firestore()
    await assertFails(setDoc(doc(fake, 'allowlist/evil@gmail.com'), {}))
  })
})
