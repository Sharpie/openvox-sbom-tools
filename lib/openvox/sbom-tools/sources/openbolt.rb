require_relative 'vanagon'

module OpenVox::SBOMTools::Sources
  class OpenBolt < Vanagon
    def initialize(data_file, repo:, path:)
      @first_tag = '5.3.0'
      @projects = %w[openbolt]

      super
    end

    def platform_list(tag, project)
      # TODO: Memoize so that JSON is not re-parsed every time.
      platforms = OpenVox::SBOMTools::Data['platforms.json']

      case tag
      when /^5/
        platforms['8.x']['vanagon']
      else
        platforms['main']['vanagon']
      end
    end
  end
end
