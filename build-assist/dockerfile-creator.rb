#! /usr/bin/env ruby

require "erb"
require "optparse"
require "json"

#
# Preparation: ( with `gcloud' container image )
#   apt-get update && apt-get instal -y ruby
#
# Usage:
#   ruby dockerfile-creator.rb create -l LANG [-s SRC_DIR] [-t TYPE] [-o OUT_DIR] [-a TEMPLATE_DIR] [-x EXTRACTOR ] <name>
#                              env -l LANG
#                              template -t TYPE -l LANG ( dump built-in template )
#                              image_types
#                              languages -a TEMPLATE_DIR
#
# Dockerfile template directory structure:
#
#   template_dir/
#                langA/
#                      Dockerfile.app
#                      Dockerfile.runner
#                langB/
#                      Dockerfile.app
#                      Dockerfile.builder
#

module DockerfileCreator
  class Error < StandardError; end

  class UnknownImageType < Error; end

  class TypeMustBeSpecified < Error; end

  class LanguageMustBeSpecified < Error; end

  class AppnameMustBeSpecified < Error; end

  class NotImplemented < Error; end

  class FileOrDirectoryNotAvailable < Error; end

  module Util
    #
    # @return [Array<String>]
    #
    def image_types
      %w[builder runner app]
    end
    module_function :image_types
  end

  #
  # find and read language version files
  #
  module Extractor
    class LangBase
      #
      # @param [String] src_dir
      #
      def initialize(src_dir:)
        @src_dir = src_dir
      end
      # @return [String]
      attr_reader :src_dir

      #
      # @return [Hash] - extracted various data
      #
      def call
        raise NotImplemented
      end
    end

    class ToolVersions
      class << self
        #
        # @param [String] src_dir
        # @return [ToolVersions]
        #
        def factory(src_dir:)
          file = versions_file(src_dir: src_dir)

          if File.exist?(file)
            new(file: file)
          end
        end

        #
        # @param [String] src_dir
        # @return [String]
        #
        def versions_file(src_dir:)
          File.join(src_dir, ".tool-versions")
        end
      end

      #
      # @param [String] file
      #
      def initialize(file:)
        @file = file
      end
      attr_reader :file

      #
      # @param [String] lang
      # @return [String, nil]
      #
      def call(lang)
        load[lang.downcase.to_sym]
      end

      #
      # eg)
      #
      # {
      #   ruby: "3.4",
      #   nodejs: "24"
      # }
      #
      # @return [Hash]
      #
      def load
        Hash[
          *File.readlines(file, chomp: true).select { |line|
            !line.start_with?("#")
          }.map { |line|
            cap = line.split(/\s+/, 3)
            [cap[0].downcase.to_sym, cap[1]]
          }.flatten
        ]
      end
    end # of ToolVersions

    #
    # system-requirements.txt resolver according to build context
    #
    class SystemRequirements
      #
      # @param [String] src_dir
      #
      def initialize(src_dir:)
        @src_dir = src_dir
      end
      # @return [String]
      attr_reader :src_dir

      #
      # @param [String] type
      # @return [Hash]
      #
      def call
        Hash[
          *Util.image_types.map { |type|
            file = File.join(src_dir, "system-requirements.#{type}.txt")

            [type.to_sym, File.exist?(file) && File.readlines(file, chomp: true).join(" ")]
          }.select { |k, v| v }.flatten
        ]
      end
    end # of SystemRequirements

    #
    # process entrypoints
    #
    class Procfile
      #
      # @param [String] src_dir
      #
      def initialize(src_dir:)
        @src_dir = src_dir
      end
      # @return [String]
      attr_reader :src_dir

      #
      # {
      #    web: "RACK_ENV=production bundle exec rackup"
      # }
      #
      # @return [Hash]
      #
      def call
        file = File.join(src_dir, "Procfile")

        if File.exist?(file)
          Hash[
            *File.readlines(file, chomp: true).select { |line|
              !line.match?(/\A\s*#/)
            }.map { |proc|
              proc =~ /\A([^:]+): (.+)\z/
              [$1.to_sym, $2]
            }.flatten
          ]
        end
      end
    end # of Procfile

    class Ruby < LangBase
      #
      # @return [Hash]
      #
      def call
        {ruby_version: ENV["RUBY_VERSION"] || ruby_version || ToolVersions.factory(src_dir: src_dir)&.call("ruby")}
      end

      #
      # @return [String, nil]
      #
      def ruby_version
        File.read(File.join(src_dir, ".ruby-version")).chomp("")
      rescue Errno::ENOENT
        nil
      end
    end

    class Nodejs < LangBase
      #
      # @return [Hash]
      #
      def env
        {
          image: "node:#{@extracted[:node_version]}-slim",
          file: ".env.image.node"
        }
      end

      #
      # @return [Hash]
      #
      def call
        @extracted = {}
        @extracted[:node_version] = ENV["NODE_VERSION"] || package_version || node_version || ToolVersions.factory(src_dir: src_dir)&.call("nodejs")
        @extracted[:node_pm] = package_manager
        version, path = yarn_info
        if version && path
          @extracted[:yarn_version] = version
          @extracted[:yarn_path] = path
        end

        @extracted
      end

      #
      # @return [Array<Hash>]
      #
      def package_managers
        [
          {manager: :pnpm, lockfile: "pnpm-lock.yaml"},
          {manager: :yarn, lockfile: "yarn.lock"},
          {manager: :npm, lockfile: "package-lock.json"}
        ]
      end

      #
      # @return [Hash(Symbol, String)]
      #
      def package_manager
        package_managers.find { |pm|
          File.exist?(File.join(src_dir, pm[:lockfile]))
        } || {manager: :npm}
      end

      #
      # extract Node.js version from .node-version
      #
      # @return [String, nil]
      #
      def node_version
        File.read(File.join(src_dir, ".node-version")).chomp("")
      rescue Errno::ENOENT
        nil
      end

      #
      # extract Node.js version from package.json
      #
      # @return [String, nil]
      #
      def package_version
        package =
          begin
            File.read(File.join(src_dir, "package.json"))
          rescue Errno::ENOENT
            nil
          end

        if package
          v = JSON.parse(package).dig("engines", "node")

          if v.match?(/\A[0-9]+/)
            v
          else
            warn <<~EOD
  package.json parser:
  `#{v}' is not supported format. Only simple version string is allowed.
            EOD

            nil
          end
        end
      end

      #
      # extract yarn version from result of printenv with docker image
      #
      # @return [Array<String>, nil]
      #
      def yarn_info
        file = File.join(src_dir, env[:file])

        if File.exist?(file)
          v = File.readlines(file, chomp: true).filter_map { |line|
            line =~ /\AYARN_VERSION=(.*)$/
            $1
          }.first

          [v, "/opt/yarn-v#{v}"]
        end
      end
    end

    #
    # for multiple-languages runtime use, concat with `_'
    #
    class Node_Ruby < LangBase # rubocop:disable Naming/ClassAndModuleCamelCase
      def call
        {
          **Ruby.new(src_dir: src_dir).call,
          **Nodejs.new(src_dir: src_dir).call
        }
      end
    end
  end # of Extractor

  class Command
    def initialize(options: Options.new(ARGV.dup))
      @options = options

      options.extractors.each do |extractor|
        require_relative extractor.sub(/\.rb\z/, "")
      end
    end
    attr_reader :options

    class Base
      #
      # @param [Options] options
      #
      def initialize(options:)
        @options = options
      end
      # @return [Options]
      attr_reader :options

      #
      # @param [String] language
      # @return [Extractor, nil]
      #
      def extractor_class(language = options.language)
        class_name = language.split("_").map { |e| e.capitalize }.join("_")
        Extractor.const_get(class_name)
      rescue NameError
        warn "No extractor Extractor::#{class_name} exists."
        nil
      end

      #
      # @param [String] language
      # @param [String] type
      # @return [String, nil]
      #
      def dockerfile_template(language = options.language, type:)
        raise LanguageMustBeSpecified.new("use --language") unless language

        template_name = "Dockerfile.#{type}.erb"

        dirs = TemplateDirCollector.new(options: options).call.reverse.select { |path|
          File.basename(path) == language
        }

        file =
          dirs.map { |d| File.join(d, template_name) }
            .find { |f| File.exist?(f) }

        file || warn("`#{template_name}' does not exist.")
      end
    end

    #
    # @return [Object]
    #
    def dispatch
      cmd = options.rest_argv.shift

      if cmd
        k = subcommands[cmd.to_sym]
        case k
        when Class
          k.new(options: options).call
        when Proc
          k.call(options: options)
        else
          puts options.parser.help
        end
      else
        puts options.parser.help
      end
    end

    class CreateDockerfile < Base
      #
      # @param [String] app_name
      # @param [Class] extractor_class
      # @return [True]
      #
      def verify_prerequirements!(app_name, extractor_class)
        raise AppnameMustBeSpecified.new("specify app name") unless app_name
        raise LanguageMustBeSpecified.new("use --language") unless options.language

        abort unless extractor_class

        true
      end

      def call
        app_name = options.rest_argv.first
        x = extractor_class(options.language)

        verify_prerequirements!(app_name, x)

        extractor = x.new(src_dir: options.src_dir)

        creator = ->(type) {
          template = dockerfile_template(options.language, type: type)

          if template # skip missing template
            requirements = Extractor::SystemRequirements.new(src_dir: options.src_dir).call
            procfile = Extractor::Procfile.new(src_dir: options.src_dir).call

            create(
              app_name: app_name,
              extractor: extractor,
              template: template,
              type: type,
              system_requirements: requirements,
              procfile: procfile,
              out_dir: options.out_dir
            )
          end
        }

        if options.type
          creator.call(options.type)
        else
          Util.image_types.each { |type| creator.call(type) }
        end
      end

      #
      # @param [String] app_name
      # @param [Extractor] extractor
      # @param [String] template
      # @param [String] type
      # @param [Hash] system_requirements
      # @param [Hash] procfile
      # @param [String] out_dir
      # @return [String]
      #
      def create(app_name:, extractor:, template:, type:, system_requirements: {}, procfile: {}, out_dir: nil)
        target =
          if out_dir
            File.open(File.join(out_dir, "Dockerfile.#{type}"), "w")
          else
            $stdout
          end

        target.puts ERB.new(File.read(template), trim_mode: "-").result_with_hash(
                      extractor.call.merge(
                        {
                          app_name: app_name,
                          out_dir: out_dir,
                          system_requirements: system_requirements,
                          procfile: procfile
                        }
                      )
                    )
      end
    end

    class DumpTemplate < Base
      def call
        raise TypeMustBeSpecified if !options.type

        dirs = TemplateDirCollector.new(options: options).call

        dirs.each { |dir|
          Dir.glob("#{dir}/*").select { |f|
            if f.include?(options.type) && File.file?(f)
              puts "\n>> #{f}"
              puts File.read(f)
            end
          }
        }
      end
    end

    class Languages < Base
      def call
        puts TemplateDirCollector.new(options: options).call(languages: true)
      end
    end

    class TemplateDirCollector < Base
      #
      # @param [bool] flatten
      # @return [Array]
      #
      def call(languages: false)
        if languages
          self.languages
        else
          options.template_dirs.map { |dir|
            Dir.glob("#{dir}/*").select { |e| File.directory?(e) }
          }.flatten
        end
      end

      #
      # @return [Array<String>]
      #
      def languages
        options.template_dirs.map { |dir|
          Dir.chdir(dir) {
            Dir.glob("*").select { |e| File.directory?(e) }
          }
        }.flatten.uniq
      end
    end # of TemplateDirCollector

    class PrintContainerEnv < Base
      #
      # @param [String] version
      # @rertun [String]
      #
      def call
        workflow_file = "printenv.yaml"

        x = extractor_class
        abort "No language info extractor for `#{options.language}'" unless x

        extractor = x.new(src_dir: options.src_dir)
        extractor.call

        File.open(workflow_file, "w") { |f|
          f.puts ERB.new(<<EOD, trim_mode: "-").result(binding)
steps:
  - name: #{extractor.env[:image]}
    entrypoint: bash
    args:
      - -c
      - 'printenv > #{extractor.env[:file]}'
EOD
        }
        puts "#{workflow_file} generated."

        `gcloud builds submit --config=#{workflow_file}`
      end
    end

    #
    # @return [Hash]
    #
    def subcommands
      cmds = {
        create: CreateDockerfile,
        env: PrintContainerEnv,
        template: DumpTemplate,
        image_types: ->(options:) {
          puts Util.image_types
        },
        languages: Languages
      }
      cmds[:commands] = ->(options:) {
        puts <<~EOD
Commands:

  #{cmds.filter_map { |name, solid| name if name != :commands }.join("\n  ")}
EOD
      }

      cmds
    end

    #
    # @param [Class] klass
    # @return [String]
    #
    def stripped_class_name(klass)
      klass.to_s.split("::").last
    end

    #
    # @param [String] glob_str
    # @param [String] dir
    # @return [Array<String>]
    #
    def glob(glob_str, dir:)
      Dir.chdir(dir) { Dir.glob(glob_str) }
    end
  end # of Command

  class Options
    def initialize(argv = ARGV.dup)
      @template_dirs = [File.join(__dir__, "dockerfile-templates")]
      @extractors = []
      @src_dir = Dir.pwd
      parser.parse!(argv)
      @rest_argv = argv
    end
    # @return [Array<String>]
    attr_reader :rest_argv
    # @return [String]
    attr_reader :language
    # @return [String]
    attr_reader :type
    # @return [String]
    attr_reader :out_dir
    # @return [String]
    attr_reader :src_dir
    # @return [Array<String>]
    attr_reader :extractors
    # @return [Array<String>]
    attr_reader :template_dirs

    #
    # @return [OptionParser]
    #
    def parser
      OptionParser.new do |opt|
        opt.set_banner(<<~EOD)
  Usage: #{opt.program_name} <command> [options]

    `commands' subcommand show command list.

        EOD
        opt.on("-l", "--language LANGUAGE") { |lang|
          @language = lang
        }
        opt.on("-t", "--type IMAGE-TYPE") { |type|
          if Util.image_types.include?(type)
            @type = type
          else
            raise UnknownImageType.new(type)
          end
        }
        opt.on("-o", "--output-dir DIR") { |dir|
          if File.exist?(dir) && File.directory?(dir) && File.writable?(dir)
            @out_dir = dir
          else
            raise FileOrDirectoryNotAvailable.new(dir)
          end
        }
        opt.on("-s", "--src-dir DIR") { |dir|
          @src_dir = dir
        }
        opt.on("-a", "--additional-template-dir DIR") { |dir|
          if File.exist?(dir) && File.directory?(dir)
            @template_dirs << dir
          else
            raise FileOrDirectoryNotAvailable.new(dir)
          end
        }
        opt.on("-x", "--extractor EXTRACTOR") { |extractor|
          if File.exist?(extractor) && File.file?(extractor)
            @extractors << File.join(Dir.pwd, extractor)
          else
            FileOrDirectoryNotAvailable.new(extractor)
          end
        }
      end
    end
  end # of Options
end

if __FILE__ == $0
  DockerfileCreator::Command.new(options: DockerfileCreator::Options.new(ARGV.dup)).dispatch
end
