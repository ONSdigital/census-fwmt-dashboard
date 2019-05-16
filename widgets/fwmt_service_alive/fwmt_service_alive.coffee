class Dashing.FWMTServiceAlive extends Dashing.Widget

  @accessor 'dead', ->
    not @get('alive')

  @accessor 'text', ->
    if @get('alive') then 'Alive' else 'Dead'
