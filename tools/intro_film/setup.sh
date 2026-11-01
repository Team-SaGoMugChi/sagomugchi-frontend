#!/bin/bash
# 렌더에 필요한 원본 에셋을 이 폴더로 복사한다(레포에 중복 커밋하지 않기 위함).
set -e
cd "$(dirname "$0")"
cp ../../assets/models/oddo_rigged.glb .
cp ../../assets/images/call_room_day.jpg ../../assets/images/call_room_night.jpg .
for w in Medium SemiBold Bold ExtraBold Black; do
  cp "node_modules/pretendard/dist/web/static/woff2/Pretendard-$w.woff2" .
done
mkdir -p out
echo "준비 완료"
