require "net/http"
require "json"

module Ingestion
  class HttpClient
    DEFAULT_TIMEOUT = 20
    RETRYABLE_STATUS_CODES = [429, 500, 502, 503, 504].freeze

    def initialize(base_url:, open_timeout: DEFAULT_TIMEOUT, read_timeout: DEFAULT_TIMEOUT, max_retries: 3)
      @base_url = base_url
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @max_retries = max_retries
    end

    def get_json(path:, params: {})
      uri = build_uri(path, params)
      attempt = 0

      loop do
        attempt += 1
        begin
          response = perform_request(uri)
          return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

          if RETRYABLE_STATUS_CODES.include?(response.code.to_i) && attempt <= @max_retries
            sleep(backoff_for(attempt))
            next
          end

          raise "HTTP #{response.code} for #{uri}"
        rescue JSON::ParserError => e
          raise "Invalid JSON response for #{uri}: #{e.message}"
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError
          raise if attempt > @max_retries

          sleep(backoff_for(attempt))
          next
        end
      end
    end

    def get_text(path:, params: {}, accept: "text/plain")
      uri = build_uri(path, params)
      attempt = 0

      loop do
        attempt += 1
        begin
          response = perform_request(uri, accept: accept)
          return response.body if response.is_a?(Net::HTTPSuccess)

          if RETRYABLE_STATUS_CODES.include?(response.code.to_i) && attempt <= @max_retries
            sleep(backoff_for(attempt))
            next
          end

          raise "HTTP #{response.code} for #{uri}"
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError
          raise if attempt > @max_retries

          sleep(backoff_for(attempt))
          next
        end
      end
    end

    private

    def build_uri(path, params)
      uri = URI.join(@base_url, path)
      query = URI.decode_www_form(String(uri.query))
      params.each { |k, v| query << [k.to_s, v.to_s] if v.present? }
      uri.query = URI.encode_www_form(query)
      uri
    end

    def perform_request(uri, accept: "application/json")
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: @open_timeout, read_timeout: @read_timeout) do |http|
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = accept
        http.request(request)
      end
    end

    def backoff_for(attempt)
      attempt**2
    end
  end
end
