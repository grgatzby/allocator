namespace :ingestion do
  desc "Run all ingestion sources (World Bank, IMF, Eurostat, OECD)"
  task all: :environment do
    Ingestion::RunAll.call
  end

  desc "Run World Bank GDP ingestion for G20"
  task world_bank: :environment do
    Ingestion::RunSource.call(data_source_code: "world_bank")
  end

  desc "Run IMF rates and commodities ingestion"
  task imf: :environment do
    Ingestion::RunSource.call(data_source_code: "imf")
  end

  desc "Run Eurostat complementary ingestion"
  task eurostat: :environment do
    Ingestion::RunSource.call(data_source_code: "eurostat")
  end

  desc "Run OECD SDMX rates ingestion"
  task oecd: :environment do
    Ingestion::RunSource.call(data_source_code: "oecd")
  end
end
