require 'json'
require 'rubygems/version'
require 'rubygems/requirement'

require_relative '../sbom-tools'
require_relative 'sources'

module OpenVox::SBOMTools
  module Data
    DATA_DIR = File.expand_path('data', __dir__).freeze

    DATA_FILES = {
      'ruby_default_gems.json' => {repo: 'janlelis/stdgems',
                                   branch: 'main',
                                   path: 'default_gems.json'},
      'ruby_bundled_gems.json' => {repo: 'janlelis/stdgems',
                                   branch: 'main',
                                   path: 'bundled_gems.json'},

      'platforms.json' => {repo: 'OpenVoxProject/shared-actions',
                           branch: 'main',
                           path: 'platforms.json'},

      'runtime_component_info.json' => {repo: 'OpenVoxProject/puppet-runtime'},
      'openvox-agent_component_info.json' => {repo: 'OpenVoxProject/openvox',
                                              path: 'packaging'},
      'openbolt_component_info.json' => {repo: 'OpenVoxProject/openbolt',
                                         path: 'packaging'},
    }

    FIRST_8X_TAG      = Gem::Requirement.new('>= 8.0.0')
    RUNTIME_8X_CUTOFF = Gem::Requirement.new('~> 8.27')
    FIRST_9X_TAG      = Gem::Requirement.new('>= 9.0.0-alpha1')

    module_function

    def file_path(name)
      File.join(DATA_DIR, name)
    end

    def read_file(name)
      File.read(file_path(name))
    end

    def [](name)
      case File.extname(name)
      when '.json'
        JSON.parse(read_file(name))
      else
        read_file(name)
      end
    end

    def update!(specific_file = nil)
      DATA_FILES.each do |name, opts|
        next unless specific_file.nil? || name == specific_file

        file = file_path(name)
        source = case name
                 when 'runtime_component_info.json'
                   OpenVox::SBOMTools::Sources::Runtime.new(file, **opts)
                 when 'openvox-agent_component_info.json'
                   OpenVox::SBOMTools::Sources::OpenVoxAgent.new(file, **opts)
                 when 'openbolt_component_info.json'
                   OpenVox::SBOMTools::Sources::OpenBolt.new(file, **opts)
                 else
                   OpenVox::SBOMTools::Sources::GitHub.new(file, **opts)
                 end

        source.update!
      end
    end

    # Return consolidated map of component => version for Vanagon projects
    def vanagon_components(project, tag)
      version = Gem::Version.new(tag)

      runtime, components = case [project, version]
                            in ['openbolt', Object]
                              ['openbolt-runtime',
                               'openbolt_component_info.json']
                            in ['openvox-agent', RUNTIME_8X_CUTOFF]
                              ['agent-runtime-8.x',
                               'openvox-agent_component_info.json']
                            in ['openvox-agent', FIRST_8X_TAG]
                              ['agent-runtime-main',
                               'openvox-agent_component_info.json']
                            in ['openvox-agent', FIRST_9X_TAG]
                              ['agent-runtime-main',
                               'openvox-agent_component_info.json']
                            else
                              raise ArgumentError,
                                format('No data for project %<project>s and tag %<tag>s',
                                       project:, tag:)
                            end

      project_components = self[components][tag]

      if project_components.nil?
        raise ArgumentError, format('No tag %<tag>s found in %<components>s',
                                    tag:, components:)
      end

      project_components = project_components['projects'][project].values.reduce(&:merge)

      runtime_name    = project_components.keys.find {|k| k =~ /-runtime$/}
      runtime_version = project_components[runtime_name]

      runtime_components = self['runtime_component_info.json'][runtime_version]
      runtime_components = runtime_components['projects'][runtime].values.reduce(&:merge)

      project_components.merge(runtime_components)
    end
  end
end
