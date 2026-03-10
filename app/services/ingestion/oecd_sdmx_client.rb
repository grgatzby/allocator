require "bigdecimal"
require "csv"

module Ingestion
  class OecdSdmxClient
    OPEN_TIMEOUT = 6
    READ_TIMEOUT = 6
    MAX_RETRIES = 0

    def initialize(http_client: nil)
      base_url = DataSource.find_by!(code: "oecd").base_url.to_s
      base_url = "#{base_url}/" unless base_url.end_with?("/")
      @http_client = http_client || HttpClient.new(
        base_url: base_url,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT,
        max_retries: MAX_RETRIES
      )
    end

    def fetch_financial_market_rate(country_iso3:, measure_codes:, source_series_key:, start_date: nil, frequency: "M")
      measure_codes.each do |measure_code|
        payload = fetch_one_measure(
          country_iso3: country_iso3,
          measure_code: measure_code,
          source_series_key: source_series_key,
          start_date: start_date,
          frequency: frequency
        )
        observations = payload.fetch(:observations, [])
        next if observations.empty?

        return payload
      ensure
        # OECD rate-limits aggressively; add a small delay to reduce HTTP 429 bursts.
        sleep(0.2)
      end

      {
        source_series_key: source_series_key,
        country_iso3: country_iso3,
        frequency: frequency,
        observations: []
      }
    end

    private

    def fetch_one_measure(country_iso3:, measure_code:, source_series_key:, start_date:, frequency:)
      # Keep a relative path so URI.join preserves "/public/rest/" prefix.
      path = "data/#{SourceMappings::OECD_FINMARK.fetch(:dataflow)}/#{series_key(country_iso3, measure_code)}"
      params = { format: "csvfile" }
      params[:startPeriod] = start_date.strftime("%Y-%m") if start_date.present?
      csv = @http_client.get_text(path: path, params: params, accept: "text/csv")

      {
        source_series_key: source_series_key,
        country_iso3: country_iso3,
        frequency: frequency,
        observations: parse_observations(csv, frequency: frequency, measure_code: measure_code)
      }
    rescue StandardError => e
      return empty_series(source_series_key, country_iso3, frequency) if e.message.include?("HTTP 404") || e.message.include?("HTTP 429")

      raise
    end

    def series_key(country_iso3, measure_code)
      "#{country_iso3}.M.#{measure_code}.PA._Z._Z._Z._Z.N"
    end

    def parse_observations(csv, frequency:, measure_code:)
      CSV.parse(csv, headers: true).filter_map do |row|
        period = row["TIME_PERIOD"]
        value = row["OBS_VALUE"]
        next if period.blank? || value.blank?

        period_date = normalize_period(period, frequency)
        next if period_date.nil?

        {
          period_date: period_date,
          value: BigDecimal(value),
          raw_payload: row.to_h.merge("matched_measure_code" => measure_code)
        }
      end
    end

    def normalize_period(period, frequency)
      case frequency
      when "A"
        Date.new(period.to_i, 12, 31)
      else
        Date.parse("#{period}-01").end_of_month
      end
    rescue Date::Error
      nil
    end

    def empty_series(source_series_key, country_iso3, frequency)
      {
        source_series_key: source_series_key,
        country_iso3: country_iso3,
        frequency: frequency,
        observations: []
      }
    end
  end
end
