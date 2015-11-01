# README #

This is a basic webapp that integrates devise with the websocket authentication.

It builds over the example at https://github.com/rails/actioncable
and it integrates with devise with the method explained at http://www.rubytutorial.io/actioncable-devise-authentication/

The goal is to put all the pieces together and get them working, not to create something original.

It illustrates a possible issue with the cable JavaScript code in actioncable 0.0.3.

## Environment ##

* Ruby 2.2.3
* Firefox 41.0.2 (Ubuntu 12.04 canonical - 1.0)
* Chromium Version 37.0.2062.120 Ubuntu 12.04 (281580) (64-bit)

## Setup ##

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

## Setup for debugging ##

Quick debugging hack to make the issue easier to spot:

* ```cd $(bundle show actioncable)```

* ```vi lib/assets/javascripts/cable/subscription.coffee``` and add three log points

    perform: (action, data = {}) ->
      console.log("1 " + JSON.stringify(data))
      data.action = action
      console.log("2 " + JSON.stringify(data))
      @send(data)

    send: (data) ->
      console.log("3 " + JSON.stringify(data))
      @consumer.send(command: "message", identifier: @identifier, data: JSON.stringify(data))

* ```vi lib/assets/javascripts/cable/consumer.coffee``` and add this log point

    send: (data) ->
      console.log("4 " + JSON.stringify(data))
      @connection.send(data)

* ```vi lib/assets/javascripts/cable/connection.coffee``` and alter the send method like this:

    send: (data) ->
      if @isOpen()
        json = JSON.stringify(data);
        @webSocket.send(json)
        console.log("5 isOpen true, " + json);
        true
      else
        console.log("5 isOpen false")
        false

## The issue ##

Register a user using the link in the form at http://localhost:3000 (it's plain devise)

Sign into the web app. The messages in the console are (Firefox with Firebug):

    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    5 isOpen false
    appearingOn hello
    AppearanceChannel#appear(data: { appearing_on: hello})
    1 {"appearing_on":"hello"}
    2 {"appearing_on":"hello","action":"appear"}
    3 {"appearing_on":"hello","action":"appear"}
    4 {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
    5 isOpen false
    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    5 isOpen true, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}

Sign in and out several times and check the messages.
It seems that ```"data": { "appearing_on": "hello" }``` is lost along the way, maybe because the socket is
closed when it's issued for the first time and when ```message``` is sent.
Finally, ```subscribe``` is sent on the open socket but there is no ```message``` sent anymore.

Add a breakpoint to assets/cable/connection.self.js lines 18 and 23. The last message changes.

    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    5 isOpen true, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    # Note: the breakpoint at line 18 should have fired, but it doesn't either in Firebug or in the dev tools.
    # The breakpoint at line 23 is reached here
    5 isOpen false
    appearingOn hello
    AppearanceChannel#appear(data: { appearing_on: hello})
    1 {"appearing_on":"hello"}
    2 {"appearing_on":"hello","action":"appear"}
    3 {"appearing_on":"hello","action":"appear"}
    4 {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
    #The breakpoint at line 18 is reached here
    5 isOpen true, {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}

It could be that the breakpoints give time to the browser to open the websocket so that the ```message``` gets through to the cable server.

Furthermore ```bin/cable``` runs the Ruby code in ```AppearanceChannel#appear(data)``` now,
because of the ```data``` key added to the JS object.

Chromium has a different behavior: it logs first a call to send with a
closed ```@webSocket```, then one with the open socket.

Without the breakpoints

    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    5 isOpen false
    appearingOn hello
    AppearanceChannel#appear(data: { appearing_on: hello})
    1 {"appearing_on":"hello"}
    2 {"appearing_on":"hello","action":"appear"}
    3 {"appearing_on":"hello","action":"appear"}
    4 {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
    5 isOpen false
    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    5 isOpen true, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}

With the breakpoints

    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    breakpoint line 23
    5 isOpen false
    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    breakpoint line 18
    5 isOpen true, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    appearingOn hello
    AppearanceChannel#appear(data: { appearing_on: hello})
    1 {"appearing_on":"hello"}
    2 {"appearing_on":"hello","action":"appear"}
    3 {"appearing_on":"hello","action":"appear"}
    4 {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
    breakpoint line 18
    5 isOpen true, {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
