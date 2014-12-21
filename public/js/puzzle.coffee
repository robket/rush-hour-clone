container = '#game'
colours = ['#ff7fff', '#7fff7f']

svg = d3.select(container)
  .append('svg')
  .attr('width', '100%')
  .attr('height', '100%')

board = 6 # positions
fr = 0.80
scalar = Math.round(100 * fr) # px
tilePadding = Math.round(16 * fr)
carPadding = Math.round(6 * fr)
moves = 0 # score (lower is better)
perfect_score = 0
max_score = 20 # max = perfect_score + max_score
win = false
identifier = d3.select(container).attr('data-identifier')

duration = moment.duration(4, 'minutes')
interval = 1000
timeLeft = 0

updateTimer = ->
  duration = moment.duration(duration.asMilliseconds() - interval, 'milliseconds')
  if duration.asMilliseconds() < 0
    clearInterval(timer)
    moves = perfect_score + max_score
    win = true # prevent overwriting score
    time = '00:00'
    d3.select('#status')
      .text('Time is up! ' + time + ' and ' + moves + ' moves')
    d3.select('#status2').text('Please wait while we save the statistics')
    $.post '/store', {"winner": { level: level, identifier: identifier, time: time, moves: moves }},
      (result) -> d3.select('#status2').text(result)
  else
    timeLeft = moment(duration.asMilliseconds()).format('mm:ss')
    d3.select('#timer').text(timeLeft)
timer = 0

intersection = (a1, a2) ->
  a1.filter (n) -> a2.indexOf(n) != -1

# Drag behaviour
[carFreedom, startXY] = [[], 0]

dragStart = (d) ->
  carFreedom = detectFreedom(d3.select(this))
  startXY = if d.orientation is 'horizontal' then d.x else d.y

dragMove = (d) ->
  axis = if d.orientation is 'horizontal' then 'x' else 'y'
  xy = d3.event[axis]

  car = d3.select(this)

  relativeXY = xy - startXY
  leftBound = (relativeXY < 0 and Math.abs(relativeXY) < carFreedom[0] * scalar)
  rightBound = (relativeXY >= 0 and relativeXY < carFreedom[1] * scalar)
  if (leftBound or rightBound)
    # Movement within bounds, move car
    car.attr(axis, d[axis] = xy)
  else
    # Collision detected, set min/max position
    if relativeXY < 0
      car.attr(axis, d[axis] = startXY - carFreedom[0] * scalar)
    else
      car.attr(axis, d[axis] = startXY + carFreedom[1] * scalar)
      if !rightBound and d.player and boardPositions(board-1, 'vertical').indexOf(d.position + d.length - 1 + carFreedom[1]) > -1
        # Player won
        if !win
          win = true
          time = d3.select('#timer').text()
          clearInterval(timer)
          d3.select('#status')
            .text('You won! ' + time + ' and ' + (moves + 1) + ' moves')
          d3.select('#status2').text('Please wait while we save your score')
          $.post '/store', {"winner": { level: level, identifier: identifier, time: time, moves: moves + 1 }},
            (result) -> d3.select('#status2').text(result)

dragEnd = (d) ->
  xy = if d.orientation is 'horizontal' then d.x else d.y
  distance = Math.round((xy - startXY) / scalar) # in tiles
  positions = boardPositions(d.position, d.orientation)
  newPosition = positions[positions.indexOf(d.position) + distance]
  description = '' + d.position + ' to ' + newPosition

  if Math.abs(distance) > 0
    if moves < (perfect_score + max_score)
      moves++
      $.post '/store', {"move": { level: level, identifier: identifier, time: timeLeft, moves: moves, description: description }},
        (result) -> console.log('Move ' + result)

    d3.select('#moves').text(moves)

  d3.select(this)
    .attr('data-position', d.position = newPosition)
    .transition()
    .attr('x', d.x = positionToX(d.position))
    .attr('y', d.y = positionToY(d.position))

drag = d3.behavior.drag()
  .origin (d) -> d
  .on('dragstart', dragStart)
  .on('drag', dragMove)
  .on('dragend', dragEnd)

# Calculate car freedom
detectFreedom = (car) ->
  pos = car.attr('data-position')
  orientation = car.attr('data-orientation')
  positions = boardPositions(pos, orientation)
  o = intersection(positions, occupiedPositions())

  upper = d3.min(o.filter (n) -> n > d3.max(carPositions(car)))
  lower = d3.max(o.filter (n) -> n < d3.min(carPositions(car)))

  # Convert to relative freedom
  if upper
    u = positions.indexOf(upper) - positions.indexOf(d3.max(carPositions(car)))
  else
    u = board - positions.indexOf(d3.max(carPositions(car)))
  l = positions.indexOf(d3.min(carPositions(car))) - positions.indexOf(lower)
  return [l - 1, u - 1]

boardPositions = (position, orientation) ->
  if orientation is 'horizontal'
    d3.range(position - position % board, position - position % board + board)
  else
    d3.range(position % board, Math.pow(board, 2), board)

occupiedPositions = ->
  positions = []
  svg.selectAll('rect.car').each (d, i) ->
    positions = positions.concat carPositions(d3.select(this))
  positions

carPositions = (car) ->
  pos = parseInt car.attr('data-position')
  length = parseInt car.attr('data-length')
  orientation = car.attr('data-orientation')
  possiblePositions = boardPositions(pos, orientation)
  if orientation is 'horizontal'
    return possiblePositions.slice(pos % board, pos % board + length)
  else
    start = Math.floor(pos/board)
    return possiblePositions.slice(start, start + length)

positionToX = (position) ->
  scalar * (position % board) + carPadding
positionToY = (position) ->
  scalar * Math.floor(position/board) + carPadding

level = d3.select(container).attr('data-level')
d3.json 'js/level'+level+'.json', (error, json) ->
  console.warn(error) if error

  perfect_score = json.perfect_score
  difficulty = json.level
  d3.select('#status').text(difficulty)
  d3.select('#perfect-score').text(perfect_score)

  squares = svg.append('g')
    .attr('class', 'tiles')
    .selectAll('rect.square')
    .data d3.range(Math.pow(board, 2))
    .enter()
    .append('rect')

  squareAttributes = squares
    .attr 'x', (i) -> scalar * (i % board) + tilePadding
    .attr 'y', (i) -> scalar * Math.floor(i/board) + tilePadding
    .attr 'height', scalar - tilePadding * 2
    .attr 'width', scalar - tilePadding * 2
    .attr 'fill', '#f4f4f7'

  for car in json.cars
    car.x = positionToX(car.position)
    car.y = positionToY(car.position)

  cars = svg.append('g')
    .attr('class', 'cars')
    .selectAll('rect.car')
    .data(json.cars)
    .enter()
    .append('rect')

  carAttributes = cars
    .attr 'class', 'car'
    .attr 'data-position', (d) -> d.position
    .attr 'data-length', (d) -> d.length
    .attr 'data-orientation', (d) -> d.orientation
    .attr 'x', (d) -> d.x
    .attr 'y', (d) -> d.y
    .attr 'height', (d) ->
      (if d.orientation is 'vertical'
        scalar * d.length
      else scalar) - carPadding * 2
    .attr 'width', (d) ->
      (if d.orientation is 'horizontal'
        scalar * d.length
      else scalar) - carPadding * 2
    .attr 'fill', (d) -> if d.player then colours[1] else colours[0]
    .call(drag)

    overlay = svg.append('rect')
      .attr 'id', 'overlay'
      .attr 'x', 0
      .attr 'y', 0
      .attr 'height', scalar * board
      .attr 'width', scalar * board
      .attr 'fill', '#444'
      .on 'click', ->
        d3.select(this).remove()
        timeLeft = moment(duration.asMilliseconds()).format('mm:ss')
        d3.select('#timer').text(timeLeft)
        timer = setInterval(updateTimer, interval)
