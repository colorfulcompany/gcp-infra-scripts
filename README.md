## Google Cloud infra setup scripts

### 目的

 * Google Cloud のうちフルマネージドで利用できるインフラの設定を手順書に頼りすぎずにある程度自動化する
     * ステージング環境などへの複製しやすさを確保する

### 設計

 * Deployment Manager API など利用してみたが思ったよりスムーズでなかったので **gcloud** SDK を利用する
 * そのうえで**レビューしやすさ**のために一部を設定ファイルっぽいテキストファイルで記述できるようにする
 * 特定の言語のセットアップに依存せず、sh script として動くようにする

### 使い方

以下のようなスクリプトを用意、

```sh
#! /bin/sh

SCRIPTS_VERSION=0.1

curl -L -O https://github.com/colorfulcompany/gcp-infra-scripts/archive/refs/tags/v${SCRIPTS_VERSION}.tar.gz
tar zxf v${SCRIPTS_VERSION}.tar.gz
mv gcp-infra-scripts-${SCRIPTS_VERSION} ./gcp-infra-scripts
```

これを Cloud Build 上で以下のように展開することで

```yaml
steps:
  - name: gcr.io/google.com/cloudsdktool/cloud-sdk:slim
    entrypoint: bash
    args:
      - ./cloudbuild/setup-infra-scripts
```

Cloud Build の workspace 上でスクリプトを呼び出せるようにする。
