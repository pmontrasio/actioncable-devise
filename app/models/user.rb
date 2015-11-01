class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  def subscribed
    logger.info "User #{self.email} subscribed"
  end

  def appear(on)
    logger.info "User #{self.email} appears on #{on}"
  end

  def disappear(options = {})
    logger.info "User #{self.email} disappears"
  end

  def away
    logger.info "User #{self.email} away"
  end
end
