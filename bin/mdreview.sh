#!/bin/sh
# markdown-review: docker 経由で markdownlint-cli2 / textlint を実行する薄いラッパー。
#
# 使い方:
#   mdreview.sh markdownlint [--fix] <file...>
#   mdreview.sh textlint <technical|blog> [--fix] <file...>
#
# ファイルは cwd（$PWD）配下の相対パス前提。cwd を /work にマウントするため、
# プロジェクトルートから呼ぶこと。config はリポジトリの config/ を read-only で注入する。
set -eu

IMAGE="markdown-review:0.2.0"

# スクリプト自身の位置から PLUGIN_ROOT を導出（CLAUDE_PLUGIN_ROOT に依存しない）。
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PLUGIN_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
CONFIG_DIR="$PLUGIN_ROOT/config"

usage="使い方: mdreview.sh markdownlint [--fix] <file...> | mdreview.sh textlint <technical|blog> [--fix] <file...>"
die() { echo "mdreview: $*" >&2; exit 1; }

# Docker 必須。ホスト linter へのフォールバックは無い。
command -v docker >/dev/null 2>&1 || die \
  "docker が見つかりません。Docker をインストールしてください（https://docs.docker.com/get-docker/）。この環境ではホスト linter へのフォールバックはありません。"

# イメージが無ければ初回のみビルドする（進行は stderr へ）。
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "mdreview: イメージ $IMAGE が無いのでビルドします（初回のみ）..." >&2
  docker build -t "$IMAGE" "$PLUGIN_ROOT/docker" 1>&2 || die "docker build に失敗しました。"
fi

[ $# -ge 1 ] || die "$usage"
TOOL="$1"; shift

# コンテナで $@ を実行する。ホストの uid/gid で走らせ、--fix の書き戻しが root 所有にならないようにする。
run() {
  docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
    -v "$PWD:/work" -w /work \
    -v "$CONFIG_DIR:/config:ro" \
    "$IMAGE" "$@"
}

case "$TOOL" in
  markdownlint)
    [ $# -ge 1 ] || die "$usage"
    run markdownlint-cli2 --config /config/markdownlint.jsonc "$@"
    ;;
  textlint)
    [ $# -ge 1 ] || die "textlint には種別 <technical|blog> が必要です。"
    TYPE="$1"; shift
    case "$TYPE" in
      technical|blog) : ;;
      *) die "未知の種別: $TYPE（technical|blog）" ;;
    esac
    [ $# -ge 1 ] || die "$usage"
    run textlint -c "/config/${TYPE}.textlintrc.json" "$@"
    ;;
  *)
    die "未知のツール: $TOOL（markdownlint|textlint）。$usage"
    ;;
esac
