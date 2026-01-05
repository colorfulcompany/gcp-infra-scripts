## script for Artifact Registry

### Preparation: ( with `gcloud' container image )

```
apt-get update && apt-get install -y ruby
```

#### example

```yaml
 name: google/cloud-sdk:slim
 entrypoint: bash
 args:
   - -c
   - |
     apt-get update && apt-get install -y ruby
     ruby <dir>/docker-repo-creator.rb -l asia create <dir>/repos.txt
```

### Usage

```
docker-repo-creator.rb [-p <project_id>] [-l <location>] create repos.txt
docker-repo-creator.rb [-p <project_id>] -l <location> -r <repository> url [image]
```

 * 変更には非対応（作成のみ）
 * できあがった Repository に対する操作を local から docker コマンドで行うには Docker 認証が必要
    * `gcloud auth configure-docker <location>-docker.pkg.dev`

#### create command

docker-repo-creator.rb create repos.txt

#### url command

display Fully Qualified Image Name (FQIN) of Repository or docker image

```
$ ruby docker-repo-creator.rb -l asia-northeast1 -r my-docker-repo url my-image
```

#### example

```
asia-northeast1-docker.pkg.dev/my-project/my-docker-repo/my-image
```

### repos.txt format

 * 1 repository : described as multilines separated by blank line
 * attribute : YAML-like tagged ( use for gcloud cmd options )
 * required keys
    * `repository`
 * optional
    * `location` ( default is `-l` option value )
    * `project` ( default is `-p` option value or `PROJECT_ID` env var )
    * `format` ( default is `docker` )

#### example

```
repository: my-docker-repo
location: asia-northeast1
```

see [gcloud artifacts repositories create  \|  Google Cloud CLI Documentation](https://cloud.google.com/sdk/gcloud/reference/artifacts/repositories/create)

