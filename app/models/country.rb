class Country < ApplicationRecord
  has_many :series, dependent: :nullify

  validates :name, :iso2, :iso3, presence: true
  validates :iso2, :iso3, uniqueness: true
end
