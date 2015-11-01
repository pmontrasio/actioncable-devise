class AppearanceChannel < ApplicationCable::Channel
  def subscribed
    current_user.subscribed #appear
  end

  def unsubscribed
    current_user.disappear
  end

  def appear(data)
    byebug
    logger.info("AppearanceChannel appear")
    current_user.appear on: data['appearing_on']
  end

  def away
    logger.info("AppearanceChannel away")
    current_user.away
  end
end
