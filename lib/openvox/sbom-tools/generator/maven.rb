require 'fileutils'
require 'tmpdir'

require_relative '../generator'
require_relative '../exec'
require_relative '../http'

module OpenVox::SBOMTools::Generator
  class Maven
    include OpenVox::SBOMTools::Exec
    include OpenVox::SBOMTools::HTTP

    CYCLONEDX_PLUGIN_VERSION = '2.9.2'.freeze

    attr_reader :file, :project, :tag

    def initialize(file, project, tag)
      @file    = file
      @project = project
      @tag     = tag
    end

    def generate!
      workdir = Dir.mktmpdir
      $stderr.puts format('Assembling SBOM for %<project>s@%<tag>s in: %<workdir>s',
                          project:, tag:, workdir:)

      artifact = case @project
                 when 'openvox-server'
                   'puppetserver'
                 when 'openvoxdb'
                   'puppetdb'
                 end

      $stderr.puts format('Downloading pom.xml for: org.openvoxprojct:%<artifact>s:%<tag>s',
                          artifact:, tag:)
      pom_url = format('https://repo.clojars.org/org/openvoxproject/%<artifact>s/%<tag>s/%<artifact>s-%<tag>s.pom',
                       artifact:, tag:)

      get_file(pom_url, File.join(workdir, 'pom.xml'))

      $stderr.puts 'Running: mvn makeAggregateBom'
      exec('mvn', "org.cyclonedx:cyclonedx-maven-plugin:#{CYCLONEDX_PLUGIN_VERSION}:makeAggregateBom",
           '-DprojectType=application',
           workdir:)

      FileUtils.cp(File.join(workdir, 'target', 'bom.json'), @file)
    end
  end
end
