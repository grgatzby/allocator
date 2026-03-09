class DataSource < ApplicationRecord
  has_many :series, dependent: :destroy
  has_many :ingestion_runs, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
