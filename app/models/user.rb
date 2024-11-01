class User < ApplicationRecord
  include ReviseAuth::Model

  has_many :collections
end
