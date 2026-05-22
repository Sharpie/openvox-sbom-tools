require_relative 'lib/openvox/sbom-tools'

namespace :vox do
  namespace :sbom do
    desc "Update data files containing component versions."
    task :update_data, [:file] do |_, args|
      OpenVox::SBOMTools::Data::DATA_FILES.each do |name, source|
        next if args[:file] && args[:file] != name

        puts "Checking: #{name}"

        local_sha   = OpenVox::SBOMTools::Data.git_hash(name)
        github_stat = OpenVox::SBOMTools::Data.github_stat(**source)

        if local_sha == github_stat[:sha]
          puts "Data file up to date: #{name}"
          next
        end

        OpenVox::SBOMTools::Data.download_file(name, download_url: github_stat[:download_url])
      end
    end
  end
end
