require 'net/http'
require 'openssl'
require 'uri'

require_relative '../sbom-tools'

module OpenVox::SBOMTools
  module HTTP
    module_function

    def http_get(url)
      url     = URI.parse(url) unless url.is_a?(URI)
      request = Net::HTTP::Get.new(url)

      response = http_do_request(url, request)

      $stderr.puts "GET - #{url}"
      response.body
    end

    def http_get_file(download_url, path)
      url     = URI.parse(download_url) unless url.is_a?(URI)
      request = Net::HTTP::Get.new(url)

      http_do_request(url, request) do |response|
        # Open file in write-binary mode and stream the body segments
        File.open(path, 'wb') do |file|
          response.read_body do |chunk|
            file.write(chunk)
          end
        end

        $stderr.puts "Downloaded - #{download_url}"
      end
    end

    private

    def http_do_request(url, request)
      Net::HTTP.start(url.hostname, url.port, use_ssl: true) do |http|
        http.request(request) do |response|
          case response
          when Net::HTTPSuccess
            yield response if block_given?

            response
          when Net::HTTPRedirection
            # GitHub frequently redirects requests to its underlying asset
            # servers. Recurse using the new location provided
            # in the 'location' header.
            redirect_url = response['location']
            $stderr.puts "Following redirect to: #{redirect_url}"
            download_file(redirect_url)
          else
            raise "Failed to download file. HTTP Status: #{response.code} - #{response.message}"
          end
        end
      end
    end
  end
end
