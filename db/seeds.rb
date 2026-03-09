seed_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts "[seed] Start seeding..."

countries = [
  ["Argentina", "AR", "ARG", "Americas"],
  ["Australia", "AU", "AUS", "Oceania"],
  ["Brazil", "BR", "BRA", "Americas"],
  ["Canada", "CA", "CAN", "Americas"],
  ["China", "CN", "CHN", "Asia"],
  ["France", "FR", "FRA", "Europe"],
  ["Germany", "DE", "DEU", "Europe"],
  ["India", "IN", "IND", "Asia"],
  ["Indonesia", "ID", "IDN", "Asia"],
  ["Italy", "IT", "ITA", "Europe"],
  ["Japan", "JP", "JPN", "Asia"],
  ["Mexico", "MX", "MEX", "Americas"],
  ["Russia", "RU", "RUS", "Europe"],
  ["Saudi Arabia", "SA", "SAU", "Asia"],
  ["South Africa", "ZA", "ZAF", "Africa"],
  ["South Korea", "KR", "KOR", "Asia"],
  ["Turkey", "TR", "TUR", "Europe"],
  ["United Kingdom", "GB", "GBR", "Europe"],
  ["United States", "US", "USA", "Americas"]
]

puts "[seed] Seeding countries (#{countries.size})..."
countries_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
countries.each do |name, iso2, iso3, region|
  Country.find_or_initialize_by(iso3: iso3).update!(
    name: name,
    iso2: iso2,
    region: region
  )
end
countries_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - countries_started_at
puts "[seed] Countries done. Total: #{Country.count} (#{format('%.2f', countries_elapsed)}s)"

data_sources = [
  ["world_bank", "World Bank", "https://api.worldbank.org"],
  ["imf", "IMF SDMX", "https://dataservices.imf.org/REST/SDMX_JSON.svc"],
  ["eurostat", "Eurostat", "https://ec.europa.eu/eurostat"],
  ["oecd", "OECD SDMX", "https://sdmx.oecd.org/public/rest"]
]

puts "[seed] Seeding data sources (#{data_sources.size})..."
data_sources_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
data_sources.each do |code, name, base_url|
  DataSource.find_or_initialize_by(code: code).update!(
    name: name,
    base_url: base_url
  )
end
data_sources_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - data_sources_started_at
puts "[seed] Data sources done. Total: #{DataSource.count} (#{format('%.2f', data_sources_elapsed)}s)"

indicators = [
  ["NY.GDP.MKTP.KD.ZG", "GDP growth (annual %)", "gdp", "%", "A"],
  ["FP.CPI.TOTL.ZG", "Inflation, consumer prices (annual %)", "inflation", "%", "A"],
  ["SHORT_RATE", "Central bank overnight rate", "rate", "%", "M"],
  ["LONG_RATE", "10Y government bond yield", "rate", "%", "M"],
  ["FX_USD", "Exchange rate vs USD", "fx", "USD", "M"],
  ["GOLD_USD_OZ", "Gold price (USD/oz)", "commodity", "USD/oz", "M"],
  ["WTI_USD_BBL", "WTI price (USD/bbl)", "commodity", "USD/bbl", "M"],
  ["HICP_YOY", "HICP inflation (YoY %)", "inflation", "%", "M"],
  ["INFLATION_CPI_YOY", "Consumer price inflation (YoY %)", "inflation", "%", "M"]
]

puts "[seed] Seeding indicators (#{indicators.size})..."
indicators_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
indicators.each do |code, name, category, unit, default_frequency|
  Indicator.find_or_initialize_by(code: code).update!(
    name: name,
    category: category,
    unit: unit,
    default_frequency: default_frequency
  )
end
indicators_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - indicators_started_at
total_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - seed_started_at
puts "[seed] Indicators done. Total: #{Indicator.count} (#{format('%.2f', indicators_elapsed)}s)"
puts "[seed] Seed completed in #{format('%.2f', total_elapsed)}s."
