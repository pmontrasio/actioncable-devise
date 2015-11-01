App.appearance = App.cable.subscriptions.create "AppearanceChannel",
  connected: ->
    # Called once the subscription has been successfully completed

  appear: ->
    console.log "AppearanceChannel#appear(data)"
    @perform 'appear', appearing_on: @appearingOn()

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
