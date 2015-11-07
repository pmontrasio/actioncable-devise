App.appearance = App.cable.subscriptions.create "AppearanceChannel",

  connected: ->
    # Called once the subscription has been successfully completed
    console.log("connected")
    @connected_to_server = true
    @replay_queue()

  appear: ->
    unless @connected_to_server
      @queue.push @appear
      console.log("queued appear")
      return

    data = appearing_on: @appearingOn()
    console.log "AppearanceChannel#appear(data: { appearing_on: " + data.appearing_on + "})"
    @perform 'appear', data

  away: ->
    unless @connected_to_server
      @queue.push @away
      console.log("queued away")
      return

    console.log "AppearanceChannel#away"
    @perform 'away'

  appearingOn: ->
    data = "hello"
    console.log "appearingOn returns #{data}"
    data
    #$('main').data 'appearing-on'

  replay_queue: ->
    console.log("replay")
    for action in @queue
      action.apply(this) # maybe there is CoffeScript way to write this line

App.appearance.queue = []

$(document).on 'page:change', ->
  App.appearance.appear()

#$(document).on 'click', '[data-behavior~=appear_away]', ->
#  App.appearance.away()
#  false
