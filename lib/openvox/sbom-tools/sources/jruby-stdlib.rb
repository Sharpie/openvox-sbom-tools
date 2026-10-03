require 'rexml'

require_relative 'gitrepo'

module OpenVox::SBOMTools::Sources
  class JRubyStdlib < GitRepo
    def initialize(data_file, repo:)
      @first_tag = '9.4.8.0'

      super
    end

    def component_info(tag)
      $stderr.puts format('Extracting stdlib gems for JRuby: %s', tag)

      # The Rake version is defined as a variable in the top-level POM file.
      main_pom = REXML::Document.new(File.read(File.join(@work_dir, 'pom.xml')))
      rake_version = REXML::XPath.match(main_pom, '//properties/rake.version').first.text

      stdlib_pom = REXML::Document.new(File.read(File.join(@work_dir, 'lib', 'pom.xml')))

      gems = REXML::XPath.each(stdlib_pom, '//dependencies/dependency [type = "gem"]').map do |dep|
        name = dep.elements['artifactId'].text

        version = if name == 'rake'
                    rake_version
                  else
                    dep.elements['version'].text
                  end

        [name, version]
      end

      gems.to_h
    end
  end
end
