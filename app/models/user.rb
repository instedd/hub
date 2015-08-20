class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :timeoutable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable,
         :validatable, :confirmable, :omniauthable,
         :lockable

  has_many :identities, dependent: :destroy
  has_many :connectors, dependent: :destroy
  has_many :event_handlers, dependent: :destroy

  def activities
    Activity.enabled? ? Activity.for(self).all : []
  end
end
