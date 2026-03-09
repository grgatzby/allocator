# app/services/ingestion/import_series.rb
module Ingestion
  class ImportSeries
    def self.call(data_source_code:, indicator_code:, country_iso3:, source_series_key:, frequency:, observations:)
      raise ArgumentError, "observations must be an Array" unless observations.is_a?(Array)

      data_source = DataSource.find_by!(code: data_source_code)
      indicator   = Indicator.find_by!(code: indicator_code)
      country     = country_iso3.present? ? Country.find_by!(iso3: country_iso3) : nil

      series = Series.find_or_initialize_by(data_source: data_source, source_series_key: source_series_key)
      ensure_series_consistency!(series, indicator, country, frequency)
      series.save! if series.new_record?

      now = Time.current
      rows = observations.filter_map do |o|
        period_date = o[:period_date]
        value = o[:value]
        next if period_date.blank? || value.blank?

        {
          series_id: series.id,
          period_date: period_date,
          value: value,
          status: o[:status],
          source_updated_at: o[:source_updated_at],
          ingested_at: now,
          raw_payload: o[:raw_payload] || {}
        }
      end

      written_rows = 0
      if rows.any?
        Observation.upsert_all(
          rows,
          unique_by: :index_observations_on_series_id_and_period_date,
          update_only: %i[value status source_updated_at ingested_at raw_payload]
        )
        written_rows = rows.size
      end

      { series: series, rows_read: observations.size, rows_written: written_rows }
    end

    def self.ensure_series_consistency!(series, indicator, country, frequency)
      if series.new_record?
        series.indicator = indicator
        series.country = country
        series.frequency = frequency
        return
      end

      mismatch = series.indicator_id != indicator.id ||
                 series.country_id != country&.id ||
                 series.frequency != frequency

      return unless mismatch

      raise ArgumentError, "Existing series metadata conflicts with ingestion payload"
    end
    private_class_method :ensure_series_consistency!
  end
end
