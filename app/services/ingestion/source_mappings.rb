module Ingestion
  module SourceMappings
    G20_ISO3 = %w[
      ARG AUS BRA CAN CHN DEU FRA GBR IND IDN ITA JPN KOR MEX RUS SAU ZAF TUR USA
    ].freeze
    EUROSTAT_GEO_TO_ISO3 = {
      "DE" => "DEU",
      "FR" => "FRA",
      "IT" => "ITA"
    }.freeze
    EUROSTAT_GEO_CODES = EUROSTAT_GEO_TO_ISO3.keys.freeze
    EU_G20_ISO3 = EUROSTAT_GEO_TO_ISO3.values.freeze
    NON_EU_G20_ISO3 = (G20_ISO3 - EU_G20_ISO3).freeze

    WORLD_BANK_GDP = {
      indicator_code: "NY.GDP.MKTP.KD.ZG",
      frequency: "A"
    }.freeze
    WORLD_BANK_INFLATION = {
      indicator_code: "FP.CPI.TOTL.ZG",
      frequency: "A"
    }.freeze

    IMF_SERIES = [
      {
        indicator_code: "SHORT_RATE",
        source_series_key: "short_rate",
        source_series_keys: %w[FIDR_PA FIMM_PA],
        frequency: "M",
        country_dependent: true
      },
      {
        indicator_code: "LONG_RATE",
        source_series_key: "long_rate",
        source_series_keys: %w[FIGB_PA FILR_PA],
        frequency: "M",
        country_dependent: true
      },
      { indicator_code: "GOLD_USD_OZ", source_series_key: "PGOLD_USD", frequency: "M", country_dependent: false },
      { indicator_code: "WTI_USD_BBL", source_series_key: "POILWTI_USD", frequency: "M", country_dependent: false }
    ].freeze

    IMF_INFLATION = {
      indicator_code: "INFLATION_CPI_YOY",
      source_series_key: "PCPI_IX",
      frequency: "M"
    }.freeze

    FX_INDICATOR = {
      indicator_code: "FX_USD",
      frequency: "M"
    }.freeze

    COUNTRY_CURRENCIES = {
      "ARG" => "ARS",
      "AUS" => "AUD",
      "BRA" => "BRL",
      "CAN" => "CAD",
      "CHN" => "CNY",
      "DEU" => "EUR",
      "FRA" => "EUR",
      "GBR" => "GBP",
      "IND" => "INR",
      "IDN" => "IDR",
      "ITA" => "EUR",
      "JPN" => "JPY",
      "KOR" => "KRW",
      "MEX" => "MXN",
      "RUS" => "RUB",
      "SAU" => "SAR",
      "ZAF" => "ZAR",
      "TUR" => "TRY",
      "USA" => "USD"
    }.freeze

    EUROSTAT_SERIES = [
      {
        indicator_code: "SHORT_RATE",
        source_series_key: "irt_st_m",
        frequency: "M",
        country_dependent: true,
        query_params: { int_rt: "IRT_DTD" }
      },
      {
        indicator_code: "LONG_RATE",
        source_series_key: "irt_lt_mcby_m",
        frequency: "M",
        country_dependent: true,
        query_params: {}
      }
    ].freeze

    EUROSTAT_HICP = {
      indicator_code: "HICP_YOY",
      source_series_key: "prc_hicp_manr",
      frequency: "M",
      query_params: {
        coicop: "CP00",
        unit: "RCH_A"
      }
    }.freeze

    OECD_FINMARK = {
      dataflow: "OECD.SDD.STES,DSD_STES@DF_FINMARK,4.0",
      frequency: "M"
    }.freeze

    OECD_RATE_SERIES = [
      {
        indicator_code: "SHORT_RATE",
        source_series_key: "short_rate",
        measure_codes: %w[IRSTCI IR3TIB],
        frequency: "M",
        country_dependent: true
      },
      {
        indicator_code: "LONG_RATE",
        source_series_key: "long_rate",
        measure_codes: %w[IRLT],
        frequency: "M",
        country_dependent: true
      }
    ].freeze
  end
end
