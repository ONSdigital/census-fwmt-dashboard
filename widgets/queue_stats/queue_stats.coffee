class Dashing.QueueStats extends Dashing.Widget
  @accessor 'messageCountText', ->
    'Message count: ' + @get('messageCount')

  onData: (data) ->
    # clear existing "status-*" classes
    $(@get('node')).attr 'class', (i, c) ->
      c.replace /\bstatus-\S+/g, ''

    # add warning if messageCount exceeds maxSafeCount
    console.log @get('maxSafeCount')
    if @get('messageCount') > @get('maxSafeCount')
      $(@get('node')).addClass "status-warning"
