require_relative 'lib/openvox/sbom-tools'

namespace :vox do
  namespace :sbom do
    desc "Update data files containing component versions."
    task :update_data, [:file] do |_, args|
      OpenVox::SBOMTools::Data.update!(args[:file])
    end

    desc "Generate SBOM for project and tag."
    task :gen, [:project, :tag] do |_, args|
      OpenVox::SBOMTools::SBOM.generate!(args[:project], args[:tag])
    end
  end
end
