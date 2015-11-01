== README

This is a basic webapp that integrates devise with the websocket authentication.
It illustrates a possible issue with the cable JavaScript code.

Environment

* Ruby 2.2.3
* Firefox 41.0.2 (Ubuntu 12.04 canonical - 1.0)
* Chromium Version 37.0.2062.120 Ubuntu 12.04 (281580) (64-bit)

    $ bundle install
    $ echo "SECRET_KEY_BASE=$(bundle exec rake secret)" > .env.development
    $ bundle exec rake db:migrate
    $ grep actioncable Gemfile.lock
      remote: git://github.com/rails/actioncable.git
        actioncable (0.0.3)
      actioncable!

* ```bundle exec rails s``` in a terminal

* ```bin/cable``` in another terminal

* Optional: ```tail -f log/development.log``` in a third terminal

Quick debugging hack to make the issue easier to spot:

* ```cd $(bundle show actioncable)```

* ```vi lib/assets/javascripts/cable/connection.coffee``` and alter the send method like this:

    send: (data) ->
      if @isOpen()
        json = JSON.stringify(data);
        @webSocket.send(json)
        console.log("isOpen true, " + json);
        console.log("isOpen true")
        true
      else
        console.log("isOpen false")
        false

Register a user using the link in the form at http://localhost:3000 (it's plain devise)

Sign into the web app. The messages in the console are (Firefox with Firebug):

    isOpen false
    AppearanceChannel#appear(data)
    appearingOn hello
    isOpen false
    isOpen true, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}

Sign in and out several times and check the messages.

Add a breakpoint to assets/cable/connection.self.js lines 18 and 23. The last message changes.

    isOpen true, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    isOpen false
    AppearanceChannel#appear(data)
    appearingOn hello
    isOpen true, {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}

It includes the ```data``` generated in ```appearance.coffee``` (the ```hello``` string.)
Furthermore ```bin/cable``` hits the breakpoint in the Ruby code at ```AppearanceChannel#appear(data)``` now,
because of the ```data``` key added to the JS object.
Apparently it's not added unless there is a breakpoint in the code. Still to investigate why.

Chromium has a different behavior: it logs first a call to send with a
closed ```@webSocket```, then one with the open socket.

    isOpen false
    isOpen true, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    AppearanceChannel#appear(data)
    appearingOn hello
    isOpen true, {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
