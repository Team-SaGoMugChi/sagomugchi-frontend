# 오또 소개 영상 · 3D 탄카츄 파이프라인

앱 첫 실행 소개 영상(`assets/videos/oddo_intro.mp4`, 27초, 9:16)과
동작이 들어간 3D 모델(`assets/models/tankachu_animated.glb`)을 만드는 도구입니다.
문구, 타이밍, 캐릭터 동작을 고친 뒤 아래 순서로 다시 뽑을 수 있습니다.

## 왜 리그를 새로 만들었나

Tripo가 자동으로 씌운 뼈대는 사람용 Mixamo 구조(손가락 뼈 30개 포함)입니다.
탄카츄는 머리가 키의 약 70%이고 팔은 몸통 옆의 짧은 돌기라서 맞지 않았습니다.
어깨 뼈 영향이 볼·머리 아래까지 번져 있어, 팔을 들면 얼굴이 같이 끌려갔습니다.

`rig.js`는 원본 메쉬와 텍스처는 그대로 두고 뼈대만 11개로 다시 만듭니다.
뼈는 몸통·머리·귀2·팔2·손2·발2입니다. 정점은 원래 가중치로 부위를 나눈 뒤
메쉬 이웃 평균으로 경계만 부드럽게 섞습니다. 앱의 Wave는 원본 팔을 축소하거나 별도 팔로 대체하지 않고 작은 각도로 흔듭니다.

## 준비

```bash
cd tools/intro_film
npm install
./setup.sh            # 원본 GLB·통화방 배경·Pretendard 폰트를 이 폴더로 복사
python3 -m http.server 8765 &   # 페이지를 로컬에서 서빙
# Chrome 경로가 다르면: export CHROME_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
```

## 영상

| 파일 | 역할 |
|---|---|
| `ad.html` | 장면 7개(빼꼼 → 감정 단어 → 통화 → 감정 읽기 → 숏폼 줌아웃 → 리포트·하트 → 로고)를 `render(t)` 하나로 그리는 페이지 |
| `snap.mjs` | 특정 시각만 캡처해 확인: `node snap.mjs 1.6,8.6,21.8 out/s && python3 sheet.py out/s out/sheet.jpg` |
| `render.mjs` | 30fps 전체 프레임을 `out/frames/`에 저장(이미 있는 프레임은 건너뜀) |
| `music.py` | 장면 전환에 맞춘 배경음악·효과음 합성 → `out/music.wav` |

```bash
node render.mjs
python3 music.py
ffmpeg -y -framerate 30 -i out/frames/%04d.jpg -i out/music.wav \
  -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p -c:a aac -b:a 160k \
  -shortest -movflags +faststart out/oddo_intro_1080.mp4
# 앱 번들용(720p)
ffmpeg -y -i out/oddo_intro_1080.mp4 -vf scale=720:1280 -c:v libx264 -preset veryfast \
  -crf 23 -c:a copy -movflags +faststart ../../assets/videos/oddo_intro.mp4
# 앱의 대체 이미지(마지막 장면)
cp out/frames/0809.jpg ../../assets/images/intro_end_card.jpg
```

엔딩 장면은 하단 27%를 앱의 `시작하기` 버튼 자리로 비워 두었습니다. 로고 위치를 바꾸면
`AppIntroductionScreen`의 버튼과 겹치지 않는지 확인하세요.

## 3D 모델(앱용)

```bash
node export.mjs && cp out/tankachu_animated.glb ../../assets/models/
```

클립: `Idle`(4초) · `Wave`(2초) · `Nod`(2초) · `Hop`(1.2초), 모두 반복 재생됩니다.
Flutter `ModelViewer(animationName: 'Wave', autoPlay: true)`로 재생합니다.
자세 실험은 `./pose.sh out/p.png '[{"armL":[-35,0,-95,1.1,1.5,1.1]}]'`로 합니다.
값은 뼈 이름별 `[x°, y°, z°, 배율x, 배율y, 배율z]`입니다.

## 2026-11-04 앱 미리보기 팔 수정

`export.html`은 `extras.js`의 분리 팔을 사용하지 않습니다. 원래 팔을 4%로 줄이던 처리와 waveArmPivot 메시·트랙을 제거했고, 원본 팔·손목의 작은 회전으로 인사합니다. 영상은 기존 연출을 유지하며 통화 장면의 표시 이름만 오또로 변경했습니다. 앱 GLB와 영상용 연출의 변경 범위를 구분합니다.

## 안내 화면 표정 (2026-11-04)

앱 모델은 기존 클립 외에 Welcome(작은 인사), Listen(갸웃하며 기다리기), Ready(끄덕임·눈웃음)를 포함합니다. export.html에서 원래 눈 주변 정점의 Blink/Happy 모프 타깃 두 개를 만들고 GLB weights 트랙으로 내보냅니다. 얼굴 데칼이나 분리 팔은 추가하지 않습니다. Ready는 앱에서 한 번 재생 후 마지막 눈웃음 자세를 유지합니다. 안내용 정면 이미지는 같은 GLB의 장면별 스튜디오 렌더이며 3D 로딩/실패 시에만 대체 표시됩니다. 소개 영상의 표정·동작에는 이 변경을 적용하지 않습니다.
