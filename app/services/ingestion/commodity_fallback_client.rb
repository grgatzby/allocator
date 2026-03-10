require "bigdecimal"
require "csv"

module Ingestion
  class CommodityFallbackClient
    STOOQ_BASE_URL = "https://stooq.com/".freeze
    FRED_BASE_URL = "https://fred.stlouisfed.org/".freeze
    DEFAULT_START_DATE = Date.new(2000, 1, 1)

    def initialize(stooq_http_client: nil, fred_http_client: nil)
      @stooq_http_client = stooq_http_client || HttpClient.new(base_url: STOOQ_BASE_URL, open_timeout: 8, read_timeout: 8, max_retries: 1)
      @fred_http_client = fred_http_client || HttpClient.new(base_url: FRED_BASE_URL, open_timeout: 8, read_timeout: 8, max_retries: 1)
    end

    def fetch_gold_usd_oz(start_date: nil)
      csv = @stooq_http_client.get_text(path: "q/d/l/", params: { s: "xauusd", i: "m" }, accept: "text/plain")
      observations = parse_stooq_monthly_close(csv, start_date: start_date)

      {
        source_series_key: "fallback:gold_usd_oz:GLOBAL",
        country_iso3: nil,
        frequency: "M",
        observations: observations
      }
    rescue StandardError
      empty_payload("fallback:gold_usd_oz:GLOBAL")
    end

    def fetch_wti_usd_bbl(start_date: nil)
      csv = @fred_http_client.get_text(path: "graph/fredgraph.csv", params: { id: "DCOILWTICO" }, accept: "text/csv")
      observations = parse_fred_daily_monthly_average(csv, start_date: start_date)

      {
        source_series_key: "fallback:wti_usd_bbl:GLOBAL",
        country_iso3: nil,
        frequency: "M",
        observations: observations
      }
    rescue StandardError
      empty_payload("fallback:wti_usd_bbl:GLOBAL")
    end

    private

    def parse_stooq_monthly_close(csv, start_date:)
      effective_start = start_date.presence || DEFAULT_START_DATE
      CSV.parse(csv, headers: true).filter_map do |row|
        date_str = row["Date"]
        close = row["Close"]
        next if date_str.blank? || close.blank?
        next if close == "0" || close == "0.0"

        period_date = Date.parse(date_str)
        next if period_date < effective_start

        {
          period_date: period_date.end_of_month,
          value: BigDecimal(close.to_s),
          raw_payload: row.to_h
        }
      end
    end

    def parse_fred_daily_monthly_average(csv, start_date:)
      effective_start = start_date.presence || DEFAULT_START_DATE
      by_month = Hash.new { |h, k| h[k] = [] }

      CSV.parse(csv, headers: true).each do |row|
        date_str = row["observation_date"]
        value = row["DCOILWTICO"]
        next if date_str.blank? || value.blank? || value == "."

        date = Date.parse(date_str)
        next if date < effective_start

        by_month[Date.new(date.year, date.month, 1)] << BigDecimal(value.to_s)
      end

      by_month.sort_by { |month, _| month }.map do |month, values|
        avg = values.sum / BigDecimal(values.size.to_s)
        {
          period_date: month.end_of_month,
          value: avg.round(6),
          raw_payload: { aggregation: "monthly_average", points: values.size }
        }
      end
    end

    def empty_payload(source_series_key)
      {
        source_series_key: source_series_key,
        country_iso3: nil,
        frequency: "M",
        observations: []
      }
    end
  end
end
