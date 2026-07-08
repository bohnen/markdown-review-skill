# markdown-review 実行ランタイム。
# markdownlint-cli2 / textlint と 2 プリセットを固定版で焼き込み、
# NODE_PATH でプリセット解決を保証する。config はマウントで注入する。
FROM node:24-alpine
WORKDIR /opt/mdreview
COPY package.json ./
# install → cache 破棄 → 不要物 prune を単一 RUN で完結させ、中間物をレイヤに残さない。
# LICENSE は法的配慮で残す。
RUN npm install --omit=dev --no-audit --no-fund \
 && npm cache clean --force \
 && find node_modules -type d \( -name test -o -name tests -o -name docs \
      -o -name example -o -name examples \) -prune -exec rm -rf {} + \
 && find node_modules -type f \( -name '*.md' -o -name '*.markdown' \
      -o -name '*.ts' -o -name '*.map' \) -delete
ENV PATH="/opt/mdreview/node_modules/.bin:${PATH}"
ENV NODE_PATH="/opt/mdreview/node_modules"
WORKDIR /work
