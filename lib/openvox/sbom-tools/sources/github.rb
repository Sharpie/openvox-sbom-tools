require 'digest/sha1'
require 'json'

require_relative '../sources'
require_relative '../http'

module OpenVox::SBOMTools::Sources
  class GitHub
    include OpenVox::SBOMTools::HTTP

    attr_reader :data_file

    def initialize(data_file, repo:, branch: 'main', path:)
      @data_file = data_file
      @repo    = repo
      @branch  = branch
      @path    = path
    end

    def update!
      $stderr.puts "Checking: #{@data_file}"
      local_sha   = git_hash
      remote_stat = github_stat

      if local_sha == remote_stat[:sha]
        $stderr.puts "Data file up to date: #{@data_file}"
        return
      end

      download_file(remote_stat[:download_url])
    end

    # private

    def git_hash
      return nil unless File.exist?(@data_file)

      content = File.read(@data_file)

      # Git header format: "blob [bytesize]\0[content]"
      header = "blob #{content.bytesize}\0"

      Digest::SHA1.hexdigest(header + content)
    end

    def github_stat
      data = http_get("https://api.github.com/repos/#{@repo}/contents/#{@path}?ref=#{@branch}")

      json = JSON.parse(data)
      { sha: json['sha'], download_url: json['download_url'] }
    end

    def download_file(download_url)
      http_get_file(download_url, @data_file)
    end
  end
end
