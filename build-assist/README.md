## Opinionated docker build tool written with Ruby


### Preparation: ( with `gcloud' container image )

```bash
apt-get update && apt-get install -y ruby
```

### dockerfile-creator.rb

#### What Is

`dockerfile-creator.rb` reads version manager files ( `.ruby-version`, `.node-version`, ... ), `system-requirements.*.txt`, `Procfile`, and generates Dockerfiles for several phases.

**Features**

 1. Detect and apply runtime Version:
    * read `.ruby_version` and `.node-version` and ...（via Extractor）
 2. Create Dockerfile from templates
    * for `builder`, `runner`, `app` phases
 3. Detect and install container-level dependencies from `system-requirements.*.txt`
 4. Detect and set `CMD` instruction ( default command ) from `Procfile`
 5. Can add templates and extractors

1 の Extractor については標準では Ruby, Node.js に対応。追加実装を与えることは可能。

2 のテンプレートについては Ruby プロジェクトおよび Ruby + Node.js 環境で ViteRuby を利用したビルドプロセスを持つプロジェクト向けのテンプレートを標準添付してある。

**Goal**

No Dockerfile maintainance required when update runtime and change dependent packages.

#### How To Use

```bash
ruby dockerfile-creator.rb create -l <language> [-s <SRC_DIR>] [-t <type>] [-o <OUT_DIR>] <app_name>
```

**examples:**

```bash
# print Dockerfile only runner image to stdout with Ruby project
$ ruby dockerfile-creator.rb create -l ruby -t runner

# create Dockerfiles into dockerfiles/ dir with Node.js and Ruby project
$ ruby dockerfile-creator.rb create -l node_ruby -s /path/to/project -o ./dockerfiles my-app my-app
```

#### Subcommands

```bash
$ ruby dockerfile-creator.rb commands
```

 * **`create`**: create Dockerfile
 * **`env`**: `builds submit printenv` with specified image
 * **`template`**: dump built-in templates
 * **`image_types`**: print supported image types
 * **`languages`**: print available ( template available ) languages

#### Images Types

 * **`builder`**: install dependencies with header file / transpile assets ...
 * **`runner`**: base image for production-level serve
 * **`app`**: `COPY`ed application and set `CMD` instruction

#### Build-in Extractors

 * **ToolVersions**
 * **SystemRequirements** : system-requirements.builder.txt for builder phase
 * **Procfile**
 * **Nodejs**: `.node-version`, `package.json`, `yarn.lock`, ...
    * switch package manager among pnpm, yarn, npm
    * env `NODE_VERSION`
 * **Ruby**: `.ruby-version`
    * env `RUBY_VERSION`

#### System Requirements

Dockerfile.builder

before:

```docker
RUN apt-get update && apt-get install -y -q --no-install-recommends
```

in **system-requirements.builder.txt**

```
libpg-dev
```

after:

```docker
RUN apt-get update && apt-get install -y -q --no-install-recommends libpg-dev
```


#### use Cases

##### 1. Basic Ruby Project

structure:
```
my-rails-app/
  .ruby-version          # 3.3.0
  Gemfile
  system-requirements.runner.txt
```


```bash
$ mkdir -p dockerfiles
$ ruby dockerfile-creator.rb create -l ruby -o dockerfiles my-rails-app
```

outputs:
- `dockerfiles/Dockerfile.runner`
- `dockerfiles/Dockerfile.app`

Dockerfile.runner

```docker
#
# Usage:
#   docker build -t my-rails-app-runner -f ./dockerfiles/Dockerfile.runner .
#

#
# Install and Store Dependencies
#

FROM ruby:3.4.7 as ruby_dev

WORKDIR /workspace

ENV BUNDLE_APP_CONFIG=/workspace/.bundle

RUN apt-get update && apt-get install -y -q --no-install-recommends
```


##### 2. Node.js + Ruby mixed Project

structure:
```
my-app/
  .ruby-version          # 3.3.0
  .node-version          # 20
  package.json
  yarn.lock
  Procfile               # web: bundle exec puma -C config/puma.rb
```

```bash
$ ruby dockerfile-creator.rb create -l node_ruby -s my-app -o my-app/docker my-app
```

##### 3. for Specific Phase only

```bash
$ ruby dockerfile-creator.rb create -l ruby -s my-app -t runner -o my-app/docker my-app
```

##### 4. Override Verion with Environment Variable

```bash
$ RUBY_VERSION=3.2.0 ruby dockerfile-creator.rb create -l ruby my-app
```

#### Add Custom Templates

place:
```
custom_templates/
  ruby/
    Dockerfile.app.erb
```

```bash
$ ruby dockerfile-creator.rb create -l ruby -a cutsom_templates my-app
```

result:
Only `Dockerfile.app.erb' should be overriden by `--additional-template-dir'

#### Add alternative Language ( Extractor and Templates )

You can add alternative Extractors and Templates.

1. **templates**:

place:
```
custom-templates/
  python/
    Dockerfile.app.erb
    Dockerfile.runner.erb
```

2. **Extractor**

extractors/python_extractor.rb

```ruby
module DockerfileCreator
  module Extractor
    class Python < LangBase
      #
      # @return [Hash]
      #
      def call
        {
          python_version: ENV["PYTHON_VERSION"] || python_version_from_file
        }
      end

      def python_version_from_file
        File.read(File.join(src_dir, ".python-version")).chomp
      rescue Errno::ENOENT
        nil
      end
    end
  end
end
```

3. **create**

```bash
$ ruby dockerfile-creator.rb create -l python -x ./extractors/python_extractor.rb -a custom_template my-app
```
