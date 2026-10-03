require_relative 'gitrepo'

module OpenVox::SBOMTools::Sources
  # Abstract base class for Vanagon data
  #
  # For each subclass, you must:
  #
  #  - Assign a value to @first_tag
  #  - Assign an Array to @projects
  #  - Implement the platform_list method
  #
  # @abstract
  class Vanagon < GitRepo
    # Sometimes the version is a git ref so extract
    # actual version numbers. Fall back to 0 if nothing
    # usable is found so everything is comparable.
    def parse_version(ver)
      Gem::Version.new(ver.to_s[/\d+(?:\.\d+)+/] || 0)
    end

    def component_info(tag)
      project_data = {}

      @projects.each do |project|
        $stderr.puts "Processing project #{project}"
        project_data[project] = {}

        result = exec('bundle', 'exec', 'vanagon', 'list', '-l',
                      workdir: @work_dir)
        # TODO: Check for failed command.
        all_platforms = result.stdout.split("\n")
        project_platforms = platform_list(tag, project)

        # Platforms will be the intersection of what is available in
        # this check-out and the list from shared-actions
        platforms = all_platforms & project_platforms

        platforms.each do |platform|
          $stderr.puts "  #{platform}"
          result = exec('bundle', 'exec', 'vanagon', 'inspect',
                        project, platform, workdir: @work_dir)

          # Sometimes, "vanagon inspect" just fails for a particular
          # platform, often due to missing artifacts. We loose some
          # small amount of data when this happens, but that is an
          # acceptable trade-off for not failing the entire operation.
          unless result.success?
            $stderr.puts "WARN Failed to gather data for #{platform}"
            next
          end

          platform_data = JSON.parse(result.stdout)
          project_data[project][platform] = platform_data.map { |h| [h['name'], h['version'] || h.dig('options', 'ref')] }.to_h
        end
      end

      component_data = project_data.values
                                   .flat_map(&:values).flatten    # [{comp1 => ver1}, {comp2 => ver2}, ...]
                                   .flat_map(&:to_a)              # [[comp1, ver1], [comp2, ver2], ...]
                                   .group_by(&:first)             # { comp1 => [[comp1, ver1], [comp1, ver2], ...], ... }
                                   .transform_values do |pairs|   # { comp1 => verN, ... }
                                     pairs.max_by { |_, ver| parse_version(ver) }.last
                                   end

      { 'components' => component_data, 'projects' => project_data }
    end
  end
end
