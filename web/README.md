# 빈무위키 웹 — 팀 레시피 공유

https://beanmuwiki-bf8c7.web.app · Firebase Spark(무료): Google 로그인 + Firestore + Hosting. 개인 계정(gkh30878) 프로젝트 `beanmuwiki-bf8c7`.

- 초대(allowlist)된 구글 계정만 로그인 후 열람. 관리자(gkh30878)가 상단 **초대** 메뉴에서 이메일 추가.
- 각자 **내 레시피**에서 ChatGPT 📦 JSON 붙여넣기 또는 앱 백업 파일(.json) 올리기 → **회원** 목록에서 다른 사람 레시피 보기.
- 보안 규칙(`firestore.rules`): 초대된 사람은 모두 읽기, 쓰기는 본인 데이터만, 초대 목록은 관리자만.

```sh
npm install
npm test             # 가져오기·표시 로직 (vitest)
npm run test:rules   # 보안 규칙 (Firestore 에뮬레이터, Java 11+ 필요)
npm run dev          # .env.development.local 에 VITE_USE_EMULATOR=1 이면 에뮬레이터 사용
npm run deploy       # 빌드 + hosting·rules 배포 (firebase login 필요)
```

`.env`(커밋 안 함)는 `npx firebase apps:sdkconfig WEB` 값으로 채운다 — `.env.example` 참고.
