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
메쉬 이웃 평균으로 경계만 부드럽게 섞습니다. 팔이 짧아서 인사할 때는
팔 뼈를 길이 방향으로 1.5배 늘립니다(카툰식 스트레치).

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
