module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      # This is a websocket so we have no warden and no session here
      # How to reuse the login made with devise?
      # http://www.rubytutorial.io/actioncable-devise-authentication/
      self.current_user = find_verified_user
      logger.info("current_user: #{self.current_user.inspect}")
      logger.add_tags "ActionCable", current_user.email
    end

    private

    def find_verified_user
      if verified_user = User.find_by(id: cookies.signed["user.id"])
        verified_user
      else
        reject_unauthorized_connection
      end
    end

  end
end
