require_relative '../sbom-tools'

module OpenVox::SBOMTools
  module Generator
    require_relative 'generator/maven'
    require_relative 'generator/vanagon'
  end
end
