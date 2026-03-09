require "bigdecimal"

module Ingestion
  class EurostatClient
    def initialize(http_client: nil)
      base_url = DataSource.find_by!(code: "eurostat").base_url.to_s
      base_url = "#{base_url}/" unless base_url.end_with?("/")
      @http_client = http_client || HttpClient.new(base_url: base_url)
    end

    def fetch_series(source_series_key:, country_iso3:, start_date: nil, frequency: "M", query_params: {})
      path = "api/dissemination/statistics/1.0/data/#{source_series_key}"
      params = {
        geo: country_iso3,
        format: "JSON"
      }.merge(query_params || {})
      params[:sinceTimePeriod] = format_since(start_date, frequency) if start_date.present?

      payload = @http_client.get_json(path: path, params: params)
      {
        source_series_key: "eu:#{source_series_key}:#{country_iso3}",
        country_iso3: country_iso3,
        frequency: frequency,
        observations: parse_observations(payload, frequency: frequency)
      }
    rescue StandardError => e
      # Eurostat may return 404 for unsupported geo/dataset combinations.
      return empty_series(source_series_key, country_iso3, frequency) if e.message.start_with?("HTTP 404")

      raise
    end

    def fetch_hicp_yoy(country_geo_code:, start_date: nil)
      payload = fetch_series(
        source_series_key: SourceMappings::EUROSTAT_HICP.fetch(:source_series_key),
        country_iso3: country_geo_code,
        start_date: start_date,
        frequency: SourceMappings::EUROSTAT_HICP.fetch(:frequency),
        query_params: SourceMappings::EUROSTAT_HICP.fetch(:query_params)
      )

      payload.merge(source_series_key: "eu:hicp_yoy:#{country_geo_code}")
    end

    private

    def parse_observations(payload, frequency:)
      values = payload["value"] || {}
      time_by_index = extract_time_by_index(payload)

      values.filter_map do |idx, value|
        period = time_by_index[idx.to_i]
        next if period.blank? || value.nil?

        period_date = normalize_period(period, frequency)
        next if period_date.nil?

        {
          period_date: period_date,
          value: BigDecimal(value.to_s),
          raw_payload: { index: idx, value: value, period: period }
        }
      end
    end

    def extract_time_by_index(payload)
      index_map = payload.dig("dimension", "time", "category", "index") || {}
      return {} unless index_map.is_a?(Hash)

      index_map.each_with_object({}) do |(period, idx), memo|
        memo[idx.to_i] = period
      end
    end

    def normalize_period(period, frequency)
      case frequency
      when "A"
        Date.new(period.to_i, 12, 31)
      when "Q"
        year, quarter = period.split("-Q")
        month = quarter.to_i * 3
        Date.new(year.to_i, month, -1)
      else
        Date.parse("#{period}-01").end_of_month
      end
    rescue Date::Error
      nil
    end

    def format_since(date, frequency)
      case frequency
      when "A" then date.strftime("%Y")
      when "Q" then "#{date.year}-Q#{((date.month - 1) / 3) + 1}"
      else date.strftime("%Y-%m")
      end
    end

    def empty_series(source_series_key, country_iso3, frequency)
      {
        source_series_key: "eu:#{source_series_key}:#{country_iso3}",
        country_iso3: country_iso3,
        frequency: frequency,
        observations: []
      }
    end
  end
end
