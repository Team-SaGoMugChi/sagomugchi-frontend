# Oddo 맥북 작업 인수인계

작성: 2026-09-22. 현재 파일, Git 이력, Codex의 ‘개발 파트 구현 시작’ 작업 기록을 확인해 작성했다. 모든 과거 대화의 원문 백업은 아니다. 비밀키와 개인 측정 원본은 포함하지 않는다.

## 가장 먼저 알아야 할 점

### 이번 전달 작업 업데이트

팀원 요청으로 새 baseline에 `voice.f0Std`(Hz), `voice.voicedRatio`(0~1), `voice.durationSec`(초), `featureVersion: 1`을 추가했다. API 응답 버전 키는 `feature_version`이며 앱이 변환해 보존한다. 과거 버전 없는 데이터는 0으로 읽고 새 값은 재측정해야 생긴다. `pitchMean`은 평균 Hz로 유지하며 중앙값·세미톤 및 얼굴 다중 프레임은 후속 협의 대상이다. 추가 항목이 기존 fusion 점수에 자동 반영되지는 않는다. 상세 계약은 실제 백엔드의 `docs/BASELINE_HANDOFF.md`.

전달 브랜치: 프론트 `17-baseline-delivery`(이슈 #17), 백엔드 `13-baseline-voice-delivery`(이슈 #13). 아래 커밋 목록은 작업 전 상태의 기록이며, 이 브랜치에는 기존 변경을 develop 위로 옮겨 새 커밋 ID가 생겼다. PR 병합 전 맥북에서 작업하려면 두 저장소에서 각각 해당 브랜치를 받아야 한다. develop만 pull하면 PR 병합 전 코드는 오지 않는다.

이번 검증: 백엔드 pytest 79개, Flutter test 83개 통과. 실제 기기에서 새 측정 후 Firebase 저장 확인은 미실시이며 다음 작업이다. Firebase 쓰기는 테스트 대역으로 계약을 검증했다.

게시 완료: [백엔드 PR #15](https://github.com/Team-SaGoMugChi/sagomugchi-backend/pull/15), [프론트 PR #19](https://github.com/Team-SaGoMugChi/sagomugchi-frontend/pull/19). 두 PR의 base는 develop이며 이 기록 시점에는 아직 병합하지 않았다. `dart fix --apply`는 수정 없음, `flutter analyze`는 문제 없음으로 완료했다. 맥북에서 각 저장소의 해당 브랜치를 받거나 PR 병합 후 develop을 갱신한다.

맥북에 GitHub 최신 develop만 있다면 윈도우의 최근 작업 전부가 있는 상태가 아니다. 2026-09-22 GitHub 원격 조회로 아래 develop 커밋을 확인했다.

| 대상 | 저장소 | 원격 develop | 윈도우 작업 HEAD |
|---|---|---|---|
| 프론트 | https://github.com/Team-SaGoMugChi/sagomugchi-frontend | `6ad90c2` | `79af94d` |
| 백엔드 | https://github.com/Team-SaGoMugChi/sagomugchi-backend | `cc695e1` | `38e873f` |

윈도우의 두 작업 브랜치는 모두 `baseline-measurement`다. 프론트 폴더는 `C:/Users/hk976/Oddo_app`, 실제 최근 백엔드 작업 폴더는 별도의 `C:/Users/hk976/Oddo_app_backend`다. 프론트 안의 `server/`는 최근 백엔드와 다르므로 최신 서버라고 가정하지 않는다. 프론트의 `origin`은 개인 저장소, `teamfront`가 팀 프론트다. 맥북의 remote 이름은 별도로 확인한다.

## develop에 없는 윈도우 작업

프론트:
- `7995807`: 계정 변경 시 baseline 측정 파일 재사용 방지.
- `fca51f5`: baseline 실제 녹음 상태 표시와 종료 동작 개선.
- `46e7a46`: 개인 측정 원본·인증 파일 Git 제외 보강.
- `79af94d`: 팀 develop 병합. develop 대비 7개 파일 차이가 있다.

백엔드:
- `fab2874`: KOTE 추론 의존성과 라이선스 고지.
- `a037bf8`: KOTE 감정분류와 팀 공통 6종 변환 연결.
- `a5f52d5`: 공식 시험셋 평가와 결과 기록.
- `22aa4d4`: 개인 측정 원본·인증 파일 Git 제외 보강.
- `38e873f`: 팀 develop 병합. develop 대비 21개 파일 차이가 있다.

이 커밋들은 확인한 develop의 조상에 포함되지 않는다. 다른 원격 브랜치에 게시되어 있는지는 이 문서 작성 시 확인하지 않았다. 기존 변경이 없는 것으로 생각하고 새로 구현하거나 덮어쓰지 않는다. 필요한 변경을 팀 절차에 맞춰 develop에 반영하거나 별도 전달받아야 한다. 이 문서만 옮기면 맥락은 전달되지만 코드까지 옮겨지지는 않는다.

## 프로젝트와 담당

Flutter 감정 일기 앱. Firebase 인증·Firestore, 별도 FastAPI 분석 서버를 사용한다. 탄카츄가 안내하는 개인 음성·얼굴 baseline과 일일 측정값을 비교하는 구조다.

확인된 역할: 한규는 개인 baseline 측정, 재영은 대화일기·감정 분석, 다경은 상담봇. 실시간 감정분석 전체를 한규 담당으로 임의 확대하지 않는다.

기존 `CLAUDE.md`, `ROADMAP.md`, 서버 README의 ‘Phase 4 시작 전’, ‘키워드 분류만 구현’, ALBERT 관련 문구에는 오래된 상태가 섞여 있다. 문서의 과거 체크리스트보다 최근 코드·커밋과 이 인수인계의 확인 시점을 함께 대조한다. 디자인·아키텍처 규칙은 계속 참고한다.

## 최근 감정분류 작업

실제 백엔드 작업 브랜치는 KOTE 모델을 로컬에서 추론한다. 팀 출력은 기쁨·슬픔·분노·불안·상처·당황의 6종을 유지한다. `POST /analyze/text`와 Step2에 연결했다. OpenAI·Clova 키 없이 KOTE 자체 테스트가 가능하다.

관련 파일: `app/services/kote_emotion.py`, `app/services/text_emotion.py`, `docs/KOTE.md`, `requirements-kote.txt`, `scripts/smoke_kote.py`, `docs/evaluations/kote-test-2026-09-16.md`.

KOTE 원래 출력을 6종으로 바꾸는 것은 잠정 대응표다. 판단 불가·복합 감정 처리가 있으며 중립 문장의 기쁨 오탐이 관찰됐다. 기록된 공식 시험셋 평가: 44종 Macro F1 0.5532, 변환된 6종 Macro F1 0.7348. 이를 오또 실제 일기 정답률 73.48%로 설명하면 안 된다. 오또용 독립 평가가 남아 있다. 이 수치는 기존 평가 문서의 기록이며 이번 인수인계 작업에서 재실행하지 않았다.

## 서버·Firebase 상태와 다음 할 일

이전 작업 기록에서는 서버 시작과 분석 실행까지 됐고 Firebase 저장 단계에서 실패했다. 이후 윈도우 사용자 인증과 저장 권한을 확인했지만, 실제 baseline 재저장 성공은 아직 확인하지 못했다. 맥북 인증은 별도로 필요하다.

사용자가 마지막으로 원한 작업 순서:
1. 최신 로컬 변경을 맥북에서도 사용할 수 있도록 확보.
2. 실제 백엔드 실행, `/health` 확인.
3. `/analyze/text`로 6종·중립·복합 감정 문장을 테스트.
4. 실제 기기에서 baseline 저장을 재시도.
5. Firebase `oddo-emotion-diary` → Firestore → `users/{uid}/meta/baseline`의 `voice`, `face`, `measuredAt` 확인.

## 맥북 환경 준비

프론트와 실제 백엔드 저장소를 각각 준비한다. Windows의 가상환경·build·캐시 폴더를 실행 환경으로 재사용하지 않는다.

프론트 루트:
```sh
flutter pub get
flutter doctor
```

실제 백엔드 루트(KOTE 코드 전달 후):
```sh
python3.11 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
python -m pip install -r requirements-kote.txt
python -m scripts.smoke_kote
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

이는 저장소 기반의 시작 절차이며 맥북에서 검증한 것은 아니다. 모델은 첫 실행 시 다운로드가 필요하며 기본 장치는 CPU다. macOS 의존성 설치 문제는 실제 오류를 보고 해결한다.

현재 프론트 `AppConfig.dev.apiBaseUrl`에는 윈도우 LAN 주소 `http://192.168.0.3:8000`이 하드코딩되어 있다. dev 실행에 dart-define만 넣어도 바뀐다고 가정하지 않는다. `main_prod.dart`는 `ODDO_API_BASE_URL`을 읽으므로 해당 진입점을 쓸 경우 다음처럼 명시한다.

```sh
flutter run -t lib/main_prod.dart --dart-define=ODDO_API_BASE_URL=http://127.0.0.1:8000
```

위 주소는 같은 맥에서 실행하는 iOS 시뮬레이터 기준이다. 실제 휴대폰에는 같은 네트워크에서 접근 가능한 맥 LAN IP를 사용하고, Android 에뮬레이터에는 보통 `10.0.2.2`를 사용한다. iOS 서명·Firebase 설정·권한·HTTP 허용 설정 등은 맥북에서 별도 검증한다.

`.env`, Firebase 인증, 모델 캐시는 Git pull로 오지 않는다. 이전 윈도우 백엔드 `.env`에는 `LLM_API_KEY`, `LLM_MODEL`, `CLOVA_SPEECH_INVOKE_URL`, `CLOVA_SPEECH_SECRET` 설정을 추가했다. 값은 안전한 별도 경로로 준비하며 문서나 커밋에 넣지 않는다. 당시에는 설정 저장만 완료했고 LLM 모델명·Clova 설정을 실제 읽어 사용하는 연결은 별도 작업으로 남아 있었다.

## 최신 팀 작업 규칙

사용자가 전달한 팀장 정정안(2026-09-21)이 기존 문서의 일반 브랜치 예시보다 우선한다.
1. 이슈 생성.
2. 이슈 Development에서 `develop`을 source로 `이슈번호-영어작업명` 브랜치 생성.
3. 커밋은 `타입: 내용 (#이슈번호)`.
4. 작업 브랜치를 push하고 base가 `develop`인 PR 작성.

이전 작업에서 push는 사전 승인 후 진행하기로 기록되어 있다. 기존 로컬 커밋을 보존하며 새 요청의 승인 범위를 확인한다. develop에 직접 임의 push하지 않는다. `_docs/`, `_screens/` 원본은 수정하지 않는다. 라우트 상수·Riverpod·디자인 토큰 등 기존 규칙을 따른다.

## 새 대화 시작용 요청

“MAC_HANDOFF.md를 먼저 읽어줘. 프론트와 백엔드 Git 상태 및 develop과의 차이를 확인하고, 윈도우에만 있던 KOTE·baseline 수정이 실제로 들어있는지 확인해줘. 오래된 ROADMAP만 보고 완료 기능을 다시 만들지 말고, 서버 연결 → 텍스트 감정분류 테스트 → baseline Firebase 저장 확인 순서로 이어가자. 비밀키는 출력하거나 커밋하지 마.”

앞으로 작업을 끝낼 때 실제 변경, 검증 결과, 미완료 사항, 커밋·PR 및 다음 작업을 이 문서에 갱신하면 기기 전환 때 다시 활용할 수 있다.
