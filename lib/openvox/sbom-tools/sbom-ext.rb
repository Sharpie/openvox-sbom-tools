require 'sbom'

require_relative '../sbom-tools'

module OpenVox::SBOMTools
  # Monkey-patch to render CPEs as top-level keys alongside PURL,
  # instead of burying them in externalReferences where many tools
  # miss them.
  module SbomExt
    def generate(project_name, sbom_data)
      super

      internal = instance_variable_get(:@generator)
      return unless internal.is_a?(Sbom::Cyclonedx::Generator)

      components = internal.to_h["components"]
      extract_cpe_from_components(components) if components
    end

    def extract_cpe_from_components(components)
      components.each do |component|
        refs = component["externalReferences"]
        next unless refs

        cpe_ref = refs.find { |r| r["type"]&.start_with?("cpe") }
        if cpe_ref
          component["cpe"] = cpe_ref["url"]
          refs.reject! { |r| r["type"]&.start_with?("cpe") }
          component.delete("externalReferences") if refs.empty?
        end
      end
    end
  end
end

class ::Sbom::Generator
  prepend ::OpenVox::SBOMTools::SbomExt
end
