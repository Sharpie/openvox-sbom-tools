require_relative '../sbom-tools'

module OpenVox::SBOMTools
  module Sources
    require_relative 'sources/github'

    require_relative 'sources/runtime'
    require_relative 'sources/openvox-agent'
    require_relative 'sources/openbolt'

    require_relative 'sources/jruby-stdlib'
  end
end
