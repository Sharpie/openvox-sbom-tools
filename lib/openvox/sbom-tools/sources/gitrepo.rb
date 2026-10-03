require 'fileutils'

require_relative '../data'
require_relative '../exec'
require_relative '../sources'

module OpenVox::SBOMTools::Sources
  # Abstract base class for GitHub Repositories
  #
  # Clones a Git repository, and iterates over each tag after the
  # `@first_tag`, and calls `component_info` to generate data on
  # components.
  #
  # For each subclass, you must:
  #
  #  - Assign a value to @first_tag
  #  - Implement the component_info method
  #
  # @abstract
  class GitRepo
    include OpenVox::SBOMTools::Exec

    CACHE_DIR = File.join(Dir.home, '.cache', 'openvox-sbom-tools').freeze

    attr_reader :data_file, :repo, :cache_dir

    def initialize(data_file, repo:, path: nil)
      @data_file    = data_file
      @repo         = repo
      @cache_dir    = FileUtils.mkdir_p(File.join(CACHE_DIR, repo)).first
      @work_dir     = path.nil? ? @cache_dir : File.join(@cache_dir, path)

      init_repo
    end

    def init_repo
      if Dir.empty?(@cache_dir)
        exec('git', 'clone', "https://github.com/#{@repo}", @cache_dir)
      else
        exec('git', 'fetch', 'origin', '--tags', '--prune', '--prune-tags',
             workdir: @cache_dir)
      end
    end

    def list_tags
      result = exec('git', 'tag', '--sort=creatordate', workdir: @cache_dir)
      # TODO: Check for failed command.
      tags = result.stdout.split("\n")

      tags[tags.find_index(@first_tag)..-1]
    end

    def update!
      $stderr.puts "Checking: #{@data_file}"

      repo_tags = list_tags
      data_tags = if File.exist?(@data_file)
                    OpenVox::SBOMTools::Data[File.basename(@data_file)].keys
                  else
                    []
                  end

      tags_to_sync = repo_tags - data_tags

      if tags_to_sync.empty?
        $stderr.puts "Data file up to date: #{@data_file}"
        return
      end

      all_data =  if File.exist?(@data_file)
                    OpenVox::SBOMTools::Data[File.basename(@data_file)]
                  else
                    {}
                  end

      Dir.chdir(@work_dir) do
        tags_to_sync.each do |tag|
          $stderr.puts "Checking out tag #{tag}..."
          exec('git', 'checkout', tag, workdir: @cache_dir)

          all_data[tag] = component_info(tag)
        end
      end

      File.write(@data_file, JSON.pretty_generate(all_data))
    end

    def component_info(tag)
      raise NotImplementedError
    end
  end
end
