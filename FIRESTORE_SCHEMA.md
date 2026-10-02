# Oddo Firestore 스키마 (v1)

> Phase-2 데이터 레이어의 **단일 기준 문서**입니다. 저장 코드를 짜는 모든 팀원(인증·미디어·AI 연동)은
> 이 구조에 맞춰 작업하세요. 구조 변경이 필요하면 이 문서를 고치는 PR을 먼저 올려 합의합니다.
>
> 대응하는 Dart 모델은 `features/<기능>/data/models/`에 있으며, 모든 모델은
> `fromJson`/`toJson`을 가집니다 (Firestore 문서 ↔ 모델 변환은 이 두 메서드만 사용).

## 0. 사전 준비 — ✅ 완료됨 (2026-07-10)

> Firestore DB는 이미 생성·설정되어 있습니다. **Phase 2 담당은 콘솔 접근 없이 바로 코드 작업을
> 시작하면 됩니다.**

- ✅ Firestore DB 생성 완료 — 리전 `asia-northeast3`(서울), 프로덕션 모드
- ✅ 보안 규칙 배포 완료 — 규칙 원본은 레포의 **`firestore.rules`** (본인 데이터만 접근 가능)
- 규칙을 수정할 일이 생기면: `firestore.rules` 편집 → PR 머지 후
  `firebase deploy --only firestore:rules --project=oddo-emotion-diary`
  (Firebase CLI 로그인 필요 — 팀장에게 요청)

## 1. 컬렉션 구조 한눈에

```
users/{uid}                              ← AppUser        (계정 프로필)
  ├─ diaries/{yyyy-MM-dd}                ← DiaryEntry     (날짜별 일기, Step1~3 산출물)
  ├─ reports/{yyyy-MM-dd}                ← EmotionReport  (날짜별 감정 리포트/행동 가이드)
  ├─ counsel_sessions/{yyyy-MM-dd}       ← CounselSession (날짜별 상담 로그, Step4)
  ├─ handoffs/{yyyy-MM-dd}               ← DiaryHandoff   (영상·상담 파트 전달 JSON, Step2 확인 때)
  └─ meta/ (고정 id 문서 3개)
      ├─ baseline                        ← BaselineProfile (얼굴/음성 기준값)
      ├─ psych                           ← PsychResult     (Big5/MBTI/성향 결과)
      └─ persona                         ← PersonaConfig   (챗봇 페르소나 설정)
```

**공통 규약**

| 규약 | 내용 |
|---|---|
| 날짜 문서 id | `yyyy-MM-dd` (예: `2026-07-10`). 조회·정렬·"작성된 날짜 집합"이 전부 이 키 기준 |
| 날짜/시각 필드 | ISO-8601 문자열 (`DateTime.toIso8601String()`) — 기존 모델 json과 통일 |
| 파일(녹음/영상) | Firestore에 넣지 않는다. **Firebase Storage**에 올리고 URL만 필드로 저장 (§3) |
| null vs 미존재 | 아직 없는 값은 필드 자체를 생략 (`toJson`에서 null 제거는 데이터소스 책임) |

## 2. 문서별 필드

### `users/{uid}` — [AppUser](lib/features/auth/data/models/app_user.dart)

| 필드 | 타입 | 설명 |
|---|---|---|
| `id` | string | uid와 동일 (역직렬화 편의용) |
| `email` | string | |
| `nickname` | string | |
| `onboardingDone` | bool | baseline+심리테스트+페르소나 완료 여부. 홈 팝업 분기 기준 |
| `createdAt` | string(ISO) | 가입 시각 |

### `users/{uid}/diaries/{yyyy-MM-dd}` — [DiaryEntry](lib/features/diary/data/models/diary_entry.dart)

| 필드 | 타입 | 설명 |
|---|---|---|
| `id` | string | 문서 id와 동일 (`yyyy-MM-dd`) |
| `date` | string(ISO) | date-only 자정 기준 |
| `transcript` | string | Step1 말하기에서 사용자가 한 말(차례별 STT를 이어 붙인 원 답변). 감정 분석·영상·상담 입력이라 다듬지 않음 |
| `diaryText` | string? | 탄카츄와의 대화를 일기 한 편으로 정제하고 Step2에서 사용자가 고친 글 — 일기 상세 본문 (2026-09-30 추가, 구 문서엔 없음) |
| `summary` | string | AI 요약(한두 문장). 요약이 없으면 `diaryText` → `transcript` 순으로 대신 저장 |
| `emotionKeywords` | string[] | 감정 키워드 |
| `videoUrl` | string? | 생성된 숏폼 Storage URL (Step3 전엔 없음) |
| `emotionIntensity` | int 0–100 | |
| `emotionStability` | int 0–100 | |
| `writtenAt` | string(ISO)? | 기록 완료 시각 (2026-07-18 추가, 구 문서엔 없을 수 있음) |

> "작성된 날짜 집합"(`recordedDaysProvider`)은 이 컬렉션의 **문서 id 목록**으로 계산한다.

### `users/{uid}/handoffs/{yyyy-MM-dd}` — [DiaryHandoff](lib/features/diary/data/models/diary_handoff.dart)

영상(Step3)·상담(Step4) 파트에 넘기는 JSON. 서버 `POST /diary/handoff`가 만들고, 앱이 Step2
"저장하고 다음 단계"에서 저장한다(같은 날 다시 확인하면 덮어씀). 각 JSON의 `설명` 필드에 필드 뜻이 한국어로 들어 있다.
`diaries`와 따로 둔다 — 기록을 끝내기 전에 저장되므로 "작성된 날짜 집합"에 섞이면 안 된다.

| 필드 | 타입 | 설명 |
|---|---|---|
| `video` | map | `oddo.diary_emotion.v1` — 원문(`transcript`)·정제 일기·요약·대화 칸, 전체 감정(Step2 결합 결과)·`arc`, `scenes`·`turning_points`·문장별 감정(KOTE). 문장별 초 단위 시간 대신 `turn`(몇 번째 답) |
| `counsel` | map | `oddo.counsel_context.v1` — `/counsel/turn` 요청 필드 이름(`emotions`·`signals`·`diary_summary`·`incongruent`) 그대로 + 대화 칸·정제 일기·감정 흐름 |
| `createdAt` | string(ISO) | 만든 시각(UTC) |

### `users/{uid}/reports/{yyyy-MM-dd}` — [EmotionReport](lib/features/diary/data/models/emotion_report.dart)

| 필드 | 타입 | 설명 |
|---|---|---|
| `date` | string(ISO) | |
| `emotionDistribution` | map<string,double> | 감정 → 비율(0–1) |
| `emotionIntensity` | int 0–100 | |
| `recoveryPossibility` | int 0–100 | |
| `analysisComment` | string | AI 분석 코멘트 |
| `behaviorGuides` | string[] | 행동 가이드 |
| `recommendedActivities` | string[] | 추천 활동 |

### `users/{uid}/counsel_sessions/{yyyy-MM-dd}` — [CounselSession](lib/features/diary/data/models/counsel_session.dart)

| 필드 | 타입 | 설명 |
|---|---|---|
| `date` | string(ISO) | |
| `startedAt` / `endedAt` | string(ISO) | |
| `messages` | map[] | `{speaker: 'oddo'\|'user', text: string}` 배열 |

### `users/{uid}/meta/baseline` — [BaselineProfile](lib/features/baseline/data/models/baseline_profile.dart)

| 필드 | 타입 | 설명 |
|---|---|---|
| `voice` | map<string,double> | 기존 6개 음성값과 3초 유성 구간의 `window*Mean`, `window*Std`, `windowCount`, `windowUsedCount`. v2 멀티모달 z-score 기준값 |
| `featureVersion` | int | 신규 측정은 2. 필드 없는 과거 데이터는 버전 0, 이전 6개 음성·4개 얼굴 계약은 버전 1로 취급하며 Step2 전 재측정 필요. API 이름은 `feature_version` |
| `face` | map<string,double> | 기존 얼굴 비율 4개와 AU 9종의 `au*LogMean`, `au*LogStd`, `auFrameCount`, `auTotalFrames`. 신규 측정은 녹음 중 1초 간격의 사진(최대 400장)을 분석한다. 녹음 기준 촬영 시각과 안내 음성 재생 여부가 있을 때는 촬영 시각 주변 0.5초의 pYIN 유성 비율로 사용자 발화·무음 프레임을 나누어 `speakingFrameCount`, `silentFrameCount`와 각 그룹의 AU 로그 평균·표준편차도 추가한다. 안내 음성 중의 프레임은 두 그룹에서 제외한다. 일기 분석은 동기화된 사진을 같은 발화·무음 그룹의 기준값과 비교한다. 그룹값이 없는 구형 v2 문서는 전체 AU 기준값을 사용한다. |
| `measuredAt` | string(ISO) | 측정 시각 |

> 키를 고정하지 않고 map으로 둔 이유: 음성/표정 특징 항목은 AI 서버(Phase 4)가 결정하며,
> 앱은 이 값을 **저장·전달만** 하고 해석하지 않는다.

### `users/{uid}/meta/psych` — [PsychResult](lib/features/psych_test/data/models/psych_result.dart)

| 필드 | 타입 | 설명 |
|---|---|---|
| `big5` | map<string,int>? | O/C/E/A/N → 0–100 점수. 미응시면 없음 |
| `big5Instrument` | string? | Big Five 산출 도구·버전. 현재 `IPIP-BFFM-50-ko` |
| `big5CompletedAt` | string(ISO)? | Big Five 50문항 완료·계산 시각 |
| `mbti` | string? | 예: `INFP`. 미응시면 없음 |
| `tendencyTraits` | string[]? | 성향 검사 결과 태그. 미응시면 없음 |
| `updatedAt` | string(ISO) | 마지막 저장 시각 |

> Big Five 문항별 응답은 민감한 원문이므로 Firestore에 저장하지 않는다. 진행 중 답변은
> 로그인 uid와 도구 버전을 함께 묶어 기기 로컬에만 임시 저장하며, 완료 후 삭제한다.
> Firestore에는 계산된 O/C/E/A/N 점수와 산출 도구·완료 시각만 저장한다.

### `users/{uid}/meta/persona` — [PersonaConfig](lib/features/persona/data/models/persona_config.dart)

| 필드 | 타입 | 설명 |
|---|---|---|
| `name` | string | 챗봇 이름 (기본 '오디', 최대 10자) |
| `tone` | string | 말투 (PersonaDummy.tones의 title 값) |
| `traits` | string[] | 성격 다중 선택 |
| `updatedAt` | string(ISO) | |

> 이름은 한 줄 1~10자, 말투는 한 줄 1~30자, 성격은 중복 없이 최대 6개(각
> 한 줄 1~20자)로 검증한다. 상담 API에는 `name`, `tone`, `traits`만 전달하고
> `updatedAt`은 전달하지 않는다.

## 3. Firebase Storage 경로

```
users/{uid}/recordings/{yyyy-MM-dd}/step1.m4a     ← Step1 음성 녹음
users/{uid}/recordings/baseline.m4a               ← baseline 음성
users/{uid}/videos/{yyyy-MM-dd}.mp4               ← 생성된 숏폼 (Phase 8)
```

규칙: 본인 경로만 접근 (`request.auth.uid == uid`), Firestore 규칙과 동일한 패턴.

## 4. 버전 관리

- 이 문서와 모델이 곧 스키마다. **필드 추가는 자유**(기존 문서와 호환되게 optional로),
  **이름 변경/삭제는 반드시 팀 합의 + 이 문서 수정 PR**과 함께.
