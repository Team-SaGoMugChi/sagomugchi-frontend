# 베이스라인 안내 영상

사용자가 제공한 baseline_intro.mp4를 안내 화면에 연결합니다. 준비 화면은 체크 3개만 표시합니다.
720×720, 16초, 오디오 트랙 없음. 원본을 재인코딩하지 않고 복사했습니다.
영상의 정사각형 비율을 유지하며 반복 재생합니다.
앱 일시정지·동작 줄이기 설정 시 멈추며, 로드 실패 시 영상 1초 지점의 포스터를 표시합니다.
기존에 제작한 일러스트 초안과 그 생성 코드는 사용하지 않습니다.

## 통화용 3D 모델

앱은 원본 외형을 보존한 별도 assets/models/oddo_call_face.glb를 사용합니다. 재생성 순서는 다음과 같습니다.

```sh
python tools/baseline_film/prototype_face_seam.py
python tools/baseline_film/build_call_motion.py --face
node tools/baseline_film/test_face_driver.cjs
```

첫 단계는 output/face-rig/에 입 경계를 분리한 사본과 검사 결과를 만듭니다. 두 번째 단계가 그 사본에 작은 듣기·대기·발화 몸짓과 1회 끄덕임을 추가해 앱 에셋을 갱신합니다. 기본 모드(옵션 없음)가 만드는 입 없는 oddo_call.glb는 이전 비교용이며 앱 배포 대상이 아닙니다.

원래 Blink/Happy와 눈/코/체형을 유지하고 AA/E/O/U 입 모프와 안쪽 명암을 추가합니다. 몸 동작 클립은 실시간 얼굴 가중치를 덮어쓰지 않습니다. CallLipTrack과 얼굴 드라이버가 TTS 시작·진행·종료에 맞춰 글자 기반 변형을 재생합니다. 이는 음성 파형 기반 정밀 립싱크가 아닙니다. 렌더러 내부 어댑터 의존성과 미검증 범위는 docs/CALL_FACE_RIG_REQUIREMENTS.md에 정리했습니다.

로컬 비교 화면·APK·기기 캡처·실험 결과는 build/ 및 output/에 두며 PR에 포함하지 않습니다.
