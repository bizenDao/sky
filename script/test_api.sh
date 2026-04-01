#!/bin/bash
set -e

log() { echo "[$(date '+%H:%M:%S')] $*"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# .env読み込み
if [ -f ".env" ]; then
  set -a
  source ".env"
  set +a
fi

# 設定
ENDPOINT_ID="${RUNPOD_ENDPOINT_ID:?RUNPOD_ENDPOINT_ID を設定してください}"
API_KEY="${RUNPOD_API_KEY:?RUNPOD_API_KEY を設定してください}"
IMAGE_PATH="${1:-$PROJECT_DIR/example_image.png}"
PROMPT="${2:-a girl in kimono gently picks up a clay bowl from the table and examines it, soft natural light from the window}"
SECONDS_LENGTH="${3:-5}"
LENGTH=$(( 16 * SECONDS_LENGTH + 1 ))

API_URL="https://api.runpod.ai/v2/${ENDPOINT_ID}"

# 画像のアスペクト比から解像度を算出（短辺480、16の倍数に補正）
read IMG_W IMG_H <<< $(python3 -c "
from PIL import Image
img = Image.open('$IMAGE_PATH')
w, h = img.size
if w < h:
    nw = 480
    nh = int(round(h * 480 / w / 16.0) * 16)
else:
    nh = 480
    nw = int(round(w * 480 / h / 16.0) * 16)
print(nw, nh)
")

log "=== Wan2.2 APIテスト ==="
log "Endpoint: ${ENDPOINT_ID}"
log "Image: ${IMAGE_PATH} (元: $(python3 -c "from PIL import Image; w,h=Image.open('$IMAGE_PATH').size; print(f'{w}x{h}')"))"
log "Resolution: ${IMG_W}x${IMG_H}"
log "Prompt: ${PROMPT}"
log "Length: ${SECONDS_LENGTH}秒 (${LENGTH}フレーム)"

# 画像をBase64エンコード
log "画像をBase64エンコード中..."
TMP_B64=$(mktemp)
base64 -i "$IMAGE_PATH" > "$TMP_B64"

# リクエストJSON作成
TMP_FULL=$(mktemp)
python3 -c "
import json, sys
with open('$TMP_B64') as f:
    img = f.read().strip()
data = {
    'input': {
        'prompt': '$PROMPT',
        'negative_prompt': 'blurry, low quality, distorted',
        'seed': 42,
        'cfg': 3.0,
        'width': $IMG_W,
        'height': $IMG_H,
        'length': $LENGTH,
        'steps': 10,
        'image_base64': img
    }
}
json.dump(data, open('$TMP_FULL', 'w'))
"
rm -f "$TMP_B64"

# ジョブ投入
log "ジョブを投入中..."
RESPONSE=$(curl -s -X POST "${API_URL}/run" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d @"$TMP_FULL")

log "レスポンス: ${RESPONSE}"

JOB_ID=$(echo "$RESPONSE" | jq -r '.id // empty')
if [ -z "$JOB_ID" ]; then
  log "エラー: ジョブIDを取得できませんでした"
  rm -f "$TMP_REQ" "$TMP_FULL"
  exit 1
fi

log "ジョブID: ${JOB_ID}"

# ステータス確認ループ
log "完了を待機中..."
while true; do
  STATUS_RESPONSE=$(curl -s "${API_URL}/status/${JOB_ID}" \
    -H "Authorization: Bearer ${API_KEY}")

  STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')
  log "ステータス: ${STATUS}"

  case "$STATUS" in
    COMPLETED)
      log "ジョブ完了!"
      WORKER_ID=$(echo "$STATUS_RESPONSE" | jq -r '.workerId // "unknown"')
      EXEC_TIME=$(echo "$STATUS_RESPONSE" | jq -r '.executionTime // "unknown"')
      log "ワーカーID: ${WORKER_ID}"
      log "実行時間: ${EXEC_TIME}ms"
      OUTPUT_PATH="${PROJECT_DIR}/test/output/output_video.mp4"
      mkdir -p "$(dirname "$OUTPUT_PATH")"
      echo "$STATUS_RESPONSE" | jq -r '.output.video' | base64 -d > "$OUTPUT_PATH"
      log "動画を保存しました: ${OUTPUT_PATH}"
      break
      ;;
    FAILED)
      log "ジョブ失敗:"
      log "$(echo "$STATUS_RESPONSE" | jq '.error')"
      break
      ;;
    IN_QUEUE|IN_PROGRESS)
      sleep 10
      ;;
    *)
      log "不明なステータス: ${STATUS}"
      log "$(echo "$STATUS_RESPONSE" | jq .)"
      break
      ;;
  esac
done

# 一時ファイル削除
rm -f "$TMP_REQ" "$TMP_FULL"

log "=== テスト完了 ==="
