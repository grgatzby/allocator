module Ingestion
  class RunAll
    SOURCES = %w[world_bank imf eurostat oecd].freeze

    def self.call
      SOURCES.map { |source| RunSource.call(data_source_code: source) }
    end
  end
end
