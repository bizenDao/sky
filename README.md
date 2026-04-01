# SKY
UI for VideoGenerator

## 前提条件

- Python 3 + `Pillow` (`pip install Pillow`)
- `jq`, `curl`, `base64` コマンド
- 環境変数または `.env` ファイルに以下を設定:
  - `RUNPOD_ENDPOINT_ID` — RunPod エンドポイントID
  - `RUNPOD_API_KEY` — RunPod APIキー

## スクリプト

### test_api.sh — Image-to-Video (I2V)

1枚の画像からプロンプトに基づいて動画を生成する。

```bash
./test_api.sh <画像パス> [プロンプト] [秒数]
```

| 引数 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| 画像パス | 任意 | `../example_image.png` | 入力画像 |
| プロンプト | 任意 | `a girl in kimono gently picks up...` | 動作の指示 |
| 秒数 | 任意 | `5` | 生成する動画の長さ（秒） |

**例:**
```bash
./test_api.sh input/akiko.jpg "女の子が手を振る" 3
```

- 入力画像のアスペクト比を維持し、短辺480pxに自動リサイズ（16の倍数に補正）
- 出力: `test/output/output_video.mp4`

---

### test_api_flf2v.sh — First-Last-Frame to Video (FLF2V)

開始画像と終了画像の2枚から、間を補間する動画を生成する。

```bash
./test_api_flf2v.sh <開始画像> <終了画像> [プロンプト] [秒数]
```

| 引数 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| 開始画像 | **必須** | — | 動画の最初のフレーム |
| 終了画像 | **必須** | — | 動画の最後のフレーム |
| プロンプト | 任意 | `the girl smoothly transitions...` | 動作の指示 |
| 秒数 | 任意 | `5` | 生成する動画の長さ（秒） |

**例:**
```bash
./test_api_flf2v.sh input/start.jpg input/end.jpg "少女が立ち上がる" 4
```

- 開始画像のアスペクト比を基準に、短辺480pxに自動リサイズ（16の倍数に補正）
- 出力: `test/output/output_flf2v.mp4`

## ディレクトリ構成

```
sky_ui/
├── input/          # 入力画像
├── output/         # 生成済み動画
├── test_api.sh     # I2V テストスクリプト
├── test_api_flf2v.sh # FLF2V テストスクリプト
└── README.md
```
