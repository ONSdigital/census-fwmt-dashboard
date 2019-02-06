class Dashing.ServiceAlive extends Dashing.Widget

  @accessor 'isDead', ->
    @get('aliveness') == false
