class DataSource < ApplicationRecord
  has_many :series
  has_many :ingestion_runs
end
