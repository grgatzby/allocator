class Indicator < ApplicationRecord
  has_many :series, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :category, presence: true
end
