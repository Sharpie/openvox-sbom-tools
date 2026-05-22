require 'digest/sha1'
require 'json'
require 'net/http'
require 'uri'

require_relative '../sbom-tools'

module OpenVox::SBOMTools
  module Data
    DATA_DIR = File.expand_path('data', __dir__).freeze

    DATA_FILES = {
      'ruby_default_gems.json' => {repo: 'janlelis/stdgems',
                                   branch: 'main',
                                   path: 'default_gems.json'},
      'ruby_bundled_gems.json' => {repo: 'janlelis/stdgems',
                                   branch: 'main',
                                   path: 'bundled_gems.json'},

      'runtime_component_info.json' => {repo: 'OpenVoxProject/puppet-runtime',
                                        branch: 'main',
                                        path: 'component_info.json'},
    }

    module_function

    def file_path(name)
      File.join(DATA_DIR, name)
    end

    def read_file(name)
      File.read(file_path(name))
    end

    def git_hash(name)
      return nil unless File.exist?(file_path(name))

      content = read_file(name)

      # Git header format: "blob [bytesize]\0[content]"
      header = "blob #{content.bytesize}\0"

      Digest::SHA1.hexdigest(header + content)
    end

    def github_stat(repo:, branch:, path:)
      url = URI.parse("https://api.github.com/repos/#{repo}/contents/#{path}?ref=#{branch}")

      request = Net::HTTP::Get.new(url)
      request['Accept'] = 'application/vnd.github+json'

      response = Net::HTTP.start(url.hostname, url.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code == '200'
        json = JSON.parse(response.body)
        { sha: json['sha'], download_url: json['download_url'] }
      else
        puts "GitHub API Error: #{response.code} - #{response.body}"
        nil
      end
    end

    def download_file(name, download_url:)
      path    = file_path(name)
      url     = URI.parse(download_url)
      request = Net::HTTP::Get.new(url)

       Net::HTTP.start(url.hostname, url.port, use_ssl: true) do |http|
        http.request(request) do |response|
          case response
          when Net::HTTPSuccess
            # Open file in write-binary mode and stream the body segments
            File.open(path, 'wb') do |file|
              response.read_body do |chunk|
                file.write(chunk)
              end
            end
            puts "Downloaded #{name} - #{download_url}"

          when Net::HTTPRedirection
            # GitHub frequently redirects requests to its underlying asset servers (e.g., codeload)
            # Recurse using the new location provided in the 'location' header
            redirect_url = response['location']
            puts "Following redirect to: #{redirect_url}"
            download_file(name, download_url: redirect_url)

          else
            raise "Failed to download file. HTTP Status: #{response.code} - #{response.message}"
          end
        end
      end
    end
  end
end
