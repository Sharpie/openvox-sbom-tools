require 'json'
require 'purl'

require_relative '../sbom-tools'
require_relative 'exec'
require_relative 'sbom'

module OpenVox::SBOMTools
  module Report
    module_function

    def components(project, tag)
      sbom = OpenVox::SBOMTools::SBOM[project, tag]

      extract_components = lambda do |bom|
        bom['components'].map do |c|
          map = {version: c['version']}
          map[:name] = if c.key?('purl')
                         Purl.parse(c['purl']).versionless.to_s
                       else
                         c['name']
                       end

          if c.key?('components')
            [map, extract_components.call(c)]
          else
            map
          end
        end
      end

      extract_components.call(sbom).flatten
    end

    def component_diff(project, from, to)
      from = components(project, from)
      to   = components(project, to)

      diff = [from, to].flatten.group_by {|c| c[:name]}.map do |name, data|
        versions = data.map {|d| d[:version]}

        if versions.count > 2
          # There should only be one component of a given name in each
          # release
          $stderr.puts format('WARN: Multiple components named %<name>s found.', name:)
          next
        elsif versions.count == 1
          if to.find {|c| c[:name] == name}
            [name, 'Added', versions[0]]
          else
            [name, versions[0], 'Removed']
          end
        elsif versions.uniq.count == 1
          # No change.
          next
        else
          [name, *versions]
        end
      end

      diff.compact
    end

    def cves(project, tag)
      sbom_path = OpenVox::SBOMTools::SBOM.file_path(project, tag)

      cve_report = OpenVox::SBOMTools::Exec.exec('grype', '--output=cyclonedx-json',
                                                 sbom_path)

      # TODO Handle failures.
      data = JSON.parse(cve_report.stdout)

      cves = data['vulnerabilities'].map do |vuln|
        id = vuln['id']
        url = vuln['source']['url']
        score = vuln['ratings'].find {|r| r['method'] == 'CVSSv31'}&.dig('score')
        affects = Purl.parse(vuln['affects'].first['ref'])
        # Grype echos PURLs back with data duplicated into the qualifiers
        # hash. Empty this out to tidy output up.
        affects.instance_variable_set(:@qualifiers, {})

        {id:, url:, score:, affects:}
      end

      cves
    end
  end
end
