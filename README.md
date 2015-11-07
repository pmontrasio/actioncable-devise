# README #

This is a basic webapp that integrates devise with the websocket authentication.

It builds over the example at https://github.com/rails/actioncable
and it integrates with devise with the method explained at http://www.rubytutorial.io/actioncable-devise-authentication/

The goal is to put all the pieces together and get them working, not to create something original.

It illustrates a possible issue with the example JavaScript code in actioncable 0.0.3.
See https://github.com/rails/actioncable/issues/118

## Environment ##

* Ruby 2.2.3
* Firefox 41.0.2 (Ubuntu 12.04 canonical - 1.0)
* Chromium Version 37.0.2062.120 Ubuntu 12.04 (281580) (64-bit)
* Opera 32.0.1948.69

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
        console.log("5 isOpen true, " + JSON.stringify(data))
        @webSocket.send(JSON.stringify(data))
        true
      else
        console.log("5 isOpen false, " + JSON.stringify(data))
        false

## The issue ##

Register a user using the link in the form at http://localhost:3000 (it's plain devise). In the example the user will be ```paolo@example.com```

Sign into the web app. The messages in the console are (Firefox with Firebug):

    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    5 isOpen false, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    appearingOn hello
    AppearanceChannel#appear(data: { appearing_on: hello})
    1 {"appearing_on":"hello"}
    2 {"appearing_on":"hello","action":"appear"}
    3 {"appearing_on":"hello","action":"appear"}
    4 {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
    5 isOpen false, {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
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
    # Note: the breakpoint at line 20 should have fired, but it doesn't either in Firebug or in the dev tools.
    # The breakpoint at line 24 is reached here
    5 isOpen false, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    appearingOn hello
    AppearanceChannel#appear(data: { appearing_on: hello})
    1 {"appearing_on":"hello"}
    2 {"appearing_on":"hello","action":"appear"}
    3 {"appearing_on":"hello","action":"appear"}
    4 {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
    #The breakpoint at line 20 is reached here
    5 isOpen true, {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}

It could be that the breakpoints give time to the browser to open the websocket so that the ```message``` gets through to the cable server.
Furthermore ```bin/cable``` runs the Ruby code in ```AppearanceChannel#appear(data)``` now: the ```data``` key added to the JS object makes ActionCable to call that method.

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
    breakpoint line 24
    5 isOpen false
    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    breakpoint line 20
    5 isOpen true, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    appearingOn hello
    AppearanceChannel#appear(data: { appearing_on: hello})
    1 {"appearing_on":"hello"}
    2 {"appearing_on":"hello","action":"appear"}
    3 {"appearing_on":"hello","action":"appear"}
    4 {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
    breakpoint line 20
    5 isOpen true, {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}


Remove those breakpoints and add one on assets/cable/connection.self.js linee 33 ``this.webSocket = new WebSocket(this.consumer.url);``. The messages are

    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    5 isOpen false, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    5 isOpen true, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    appearingOn hello
    AppearanceChannel#appear(data: { appearing_on: hello})
    1 {"appearing_on":"hello"}
    2 {"appearing_on":"hello","action":"appear"}
    3 {"appearing_on":"hello","action":"appear"}
    4 {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
    5 isOpen true, {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}

which is what one would expect: failure to subscribe due to a closed websocket, retry, success, console.log from ```channels/subscriptions/appearance.coffee```
and log messages 1 to 5 from the ActionCable js library sending the message to the server. And this in the server log:

    1 [ActionCable] [paolo@example.com] Registered connection (gid://cable/User/1)
    2 [ActionCable] [paolo@example.com] User paolo@example.com subscribed
    3 [ActionCable] [paolo@example.com] AppearanceChannel is transmitting the subscription confirmation
    4 [ActionCable] [paolo@example.com] AppearanceChannel#appear({"appearing_on"=>"hello"})
    5 [ActionCable] [paolo@example.com] AppearanceChannel appear
    6 [ActionCable] [paolo@example.com] User paolo@example.com appears on {:on=>"hello"}

Lines 2, 5 and 6 are my own debug messages. The others are from the framework.

Delete the breakpoint. Set a breakpoint on assets/cable/connection.self.js linee 33 ``return this.isState("open");``. Logout and login. Hit F8 to continue until you login.
Check the console: no messages yet when the browser hits the breakpoint.

Step into the function and follow it.

Is it possible that the first subscribe message without the debugger leaves no time to the browser to establish the connection to the server?

Add more console.log to the gem


```vi lib/assets/javascripts/cable/subscriptions.coffee```

    add: (subscription) ->
      @subscriptions.push(subscription)
      @notify(subscription, "initialized")
      console.log("0 subscribe")
      @sendCommand(subscription, "subscribe")

```vi lib/assets/javascripts/cable/connection.coffee```

    isOpen: ->
      state = @isState("open")
      console.log("0 open = " + state)
      state

Delete the breakpoints, logout, login

    0 subscribe
    0 open = false
    0 subscribe
    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    0 open = false
    5 isOpen false, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    appearingOn hello
    AppearanceChannel#appear(data: { appearing_on: hello})
    1 {"appearing_on":"hello"}
    2 {"appearing_on":"hello","action":"appear"}
    3 {"appearing_on":"hello","action":"appear"}
    4 {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
    0 open = false
    5 isOpen false, {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
    0 open = true
    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    0 open = true
    5 isOpen true, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}


On the server

    [ActionCable] [paolo@example.com] Registered connection (gid://cable/User/1)
    [ActionCable] [paolo@example.com] User paolo@example.com subscribed
    [ActionCable] [paolo@example.com] AppearanceChannel is transmitting the subscription confirmation


It seems that the problem is that the example I build upon is somewhat misleading.
The  call to ```App.appearance.appear()``` has no chance of succeeding until the websocket is open and connected so this code from the gem README

    $(document).on 'page:change', ->
      App.appearance.appear()

will always fail unless a breakpoint gives ActionCable enough time to connect to the server.
A nice solution could be building a queuing mechanism in the ActionCable js code and replay all the queued messages after the connection is established (maybe in ```Cable.Subscriptions```)
A workaround is to build the queue in the code of the channel like I did as a proof of concept. Check ```/app/assets/javascripts/channels/subscriptions/appearance.coffee```

That gives the expected behavior. Client side log:

    0 subscribe
    0 open = false
    0 subscribe
    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    0 open = false
    5 isOpen false, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    queued appear
    0 open = true
    4 {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    0 open = true
    5 isOpen true, {"command":"subscribe","identifier":"{\"channel\":\"AppearanceChannel\"}"}
    connected
    replay
    appearingOn returns hello
    AppearanceChannel#appear(data: { appearing_on: hello})
    1 {"appearing_on":"hello"}
    2 {"appearing_on":"hello","action":"appear"}
    3 {"appearing_on":"hello","action":"appear"}
    4 {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}
    0 open = true
    5 isOpen true, {"command":"message","identifier":"{\"channel\":\"AppearanceChannel\"}","data":"{\"appearing_on\":\"hello\",\"action\":\"appear\"}"}

Server side log:

    [ActionCable] [paolo@example.com] Registered connection (gid://cable/User/1)
    [ActionCable] [paolo@example.com] User paolo@example.com subscribed
    [ActionCable] [paolo@example.com] AppearanceChannel is transmitting the subscription confirmation
    [ActionCable] [paolo@example.com] AppearanceChannel#appear({"appearing_on"=>"hello"})
    [ActionCable] [paolo@example.com] AppearanceChannel appear
    [ActionCable] [paolo@example.com] User paolo@example.com appears on {:on=>"hello"}
