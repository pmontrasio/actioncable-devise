App.appearance = App.cable.subscriptions.create "AppearanceChannel",
  connected: ->
    # Called once the subscription has been successfully completed

  appear: ->
    data = appearing_on: @appearingOn()
    console.log "AppearanceChannel#appear(data: { appearing_on: " + data.appearing_on + "})"
    @perform 'appear', data

  away: ->
    console.log "AppearanceChannel#away"
    @perform 'away'

  appearingOn: ->
    console.log "appearingOn hello"
    'hello'
    #$('main').data 'appearing-on'

$(document).on 'page:change', ->
  App.appearance.appear()

#$(document).on 'click', '[data-behavior~=appear_away]', ->
#  App.appearance.away()
#  false
