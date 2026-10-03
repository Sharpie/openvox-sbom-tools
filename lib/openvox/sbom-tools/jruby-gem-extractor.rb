require 'prism'

require_relative '../sbom-tools'

module OpenVox::SBOMTools
  # Visitor for the Prism parser that extracts the `default_gems` and
  # `bundled_gems` lists definied in `lib/pom.rb`.
  #
  # @see https://github.com/jruby/jruby/blob/master/lib/pom.rb
  class JRubyGemExtractor < Prism::Visitor
    GEM_LISTS = %i[default_gems bundled_gems]

    def self.parse(path)
      parsed    = Prism.parse_file(path)
      extractor = self.new

      parsed.value.accept(extractor)

      extractor.data
    end

    attr_reader :data

    def initialize
      @data = {}
    end

    def visit_local_variable_write_node(node)
      if GEM_LISTS.include?(node.name)
        @data[node.name] = node.value.elements.map do |array_entry|
          name, version, _ = array_entry.elements

          [name.unescaped, version.unescaped]
        end.to_h
      end
    end
  end
end
