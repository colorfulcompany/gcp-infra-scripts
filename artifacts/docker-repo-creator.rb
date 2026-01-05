#! /usr/bin/env ruby

#
# Preparation: ( with `gcloud' container image )
#   apt-get update && apt-get install -y ruby
#
# Usage:
#   1. create-docker-repo [-p <project_id>] [-l <location>] create repos.txt
#   2. create-docker-repo [-p <project_id>] -l <location> -r <repository> url [image]
#

require "yaml"
require "optparse"

module GoogleArtifact
  class Error < StandardError; end

  class RepositoryMustBeSpecified < Error; end

  class LocationMustBeSpecified < Error; end

  #
  # Hash extension ( change the matching conditions and enforce specific keys fuifilled )
  #
  module Repository
    #
    # @return [bool]
    #
    def ready_to_create?
      self[:repository] && self[:location]
    end

    #
    # @param [Repository] other
    # @return [bool]
    #
    def eql?(other)
      self[:repository] == other[:repository]
    end
  end

  module Command
    #
    # @param [Array<String>] argv
    # @param [IO] io
    # @param [Options] options
    #
    def call(argv = ARGV.dup, io: IO.new, options: Options.new)
      commands = {create: Creator, url: Resolver}

      cmd, target = options.argv
      command = commands[cmd.to_sym]

      if command
        command.new.call(target, io: io, options: options)
      else
        abort "`#{cmd}' is not defined as command"
      end
    end
    module_function :call

    class Creator
      #
      # @param [String] file
      # @param [IO] io
      # @param [Options] options
      #
      def call(file, io:, options:)
        repos_already_defined = io.read_repos
        repos_want_to_create = io.read_config(file)
        repos = repos_want_to_create - repos_already_defined

        if repos.size > 0
          repos.each { |r| io.create_repo(r, options) }
        else
          puts "Nothing to do. ( repos you want to create are already defined or have no contents."
        end
      end
    end

    class Resolver
      #
      # @param [String] name
      # @param [IO] io
      # @param [Options] options
      #
      def call(name, io:, options:)
        raise RepositoryMustBeSpecified.new("use -r") unless options.repository
        raise LocationMustBeSpecified.new("use -l") unless options.location

        format = "%s"
        format += "\n" if $stdout.tty?

        printf(format, Util.encode_repo(project: options.project, location: options.location, repository: options.repository, image: name))
      end
    end
  end

  class Options
    #
    # @param [Array<String>] argv
    # @param [String] project
    #
    def initialize(argv = ARGV.dup, project: ENV["PROJECT_ID"])
      @project = project
      @argv = argv
      parser.parse!(argv)
    end
    # @return [Array<String>]
    attr_reader :argv
    # @return [String]
    attr_reader :project
    # @return [String]
    attr_reader :location
    # @return [String]
    attr_reader :repository

    #
    # @return [OptionParser]
    #
    def parser
      OptionParser.new do |opt|
        opt.on("-p", "--project PROJECT") { |project|
          @project = project
        }
        opt.on("-l", "--location LOCATION") { |location|
          @location = location
        }
        opt.on("-r", "--repository REPOSITORY") { |repository|
          @repository = repository
        }
      end
    end
  end

  class IO
    #
    # @return [String]
    #
    def list_cmd
      `gcloud artifacts repositories list --format yaml 2> /dev/null`
    end

    #
    # @return [Array<Repository>]
    #
    def read_repos
      repos = YAML.load_stream(list_cmd, symbolize_names: true)
      repos.select { |repo| repo[:format] == "DOCKER" }.map { |repo|
        {
          createTime: repo[:createTime],
          updateTime: repo[:updateTime]
        }.merge(Util.decode_reponame(repo[:name])).extend(Repository)
      }
    end

    #
    # @param [String] file
    # @return [Array<Repository>]
    #
    def read_config(file)
      return [] unless file

      repos = File.readlines(file, "")
      repos.map { |repo|
        YAML.safe_load(repo.chomp, symbolize_names: true).extend(Repository)
      }
    end

    #
    # @param [Repository] repo
    # @param [Options] options
    #
    def create_repo(repo, options)
      repo[:location] = options.location unless repo[:location]
      repo[:format] = "docker" unless repo[:format]
      repo[:project] = options.project unless repo[:project]

      if repo.ready_to_create?
        `gcloud artifacts repositories create #{repo[:repository]} --location #{repo[:location]} --repository-format #{repo[:format]} --project #{repo[:project]}`
      else
        warn "can't create #{repo}, it need have attributes :repository and :locatoin"
      end
    end
  end

  module Util
    #
    # turn repository name to Repository base info ( Hash extended )
    #
    # projects/xxxx-xxx-xx/locations/asia-northeast1/repositories/cloud-run-source-deploy
    #
    # {
    #   project: "xxxx-xxx-xx",
    #   location: "asia-northeast1",
    #   repository: "cloud-run-source-deploy"
    # }
    #
    # @param [String] name
    # @return [Hash]
    #
    def decode_reponame(name)
      /projects\/([^\/]+)\/locations\/([^\/]+)\/repositories\/([^\/]+)/ =~ name

      {
        project: $1,
        location: $2,
        repository: $3
      }
    end
    module_function :decode_reponame

    #
    # @param [String] project
    # @param [String] location
    # @param [String] repository
    # @param [String, nil] image
    # @return [String]
    #
    def encode_repo(project:, location:, repository:, image: nil)
      url = "#{location}-docker.pkg.dev/#{project}/#{repository}"
      url += "/#{image}" if image
      url
    end
    module_function :encode_repo

    #
    # @param [String] fqin
    # @return [String]
    #
    def registry_of(fqin)
      fqin.split("/").first
    end
    module_function :registry_of
  end
end

if __FILE__ == $0
  GoogleArtifact::Command.call(ARGV.dup)
end
