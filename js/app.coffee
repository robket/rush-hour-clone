container = '#game'
colours = ['#ff7fff', '#7fff7f']

svg = d3.select(container)
  .append('svg')
  .attr('width', '100%')
  .attr('height', '100%')

board = 6 # positions
scalar = 100 # px
tilePadding = 16
carPadding = 6

intersection = (a1, a2) ->
  a1.filter (n) -> a2.indexOf(n) != -1

# Drag behaviour
carFreedom = []
startPosition = []
dragStart = (d) ->
  carFreedom = detectFreedom(d3.select(this))
  console.log carFreedom
  startPosition = [d.x, d.y]
dragMove = (d) ->
  xy = [d3.event.x, d3.event.y]
  car = d3.select(this)
  relativeXY = xy.map (n, i) -> n - startPosition[i]
  if d.orientation == 'horizontal'
    console.log [relativeXY[0], carFreedom[1] * scalar]
    leftBound = (relativeXY[0] < 0 and Math.abs(relativeXY[0]) < carFreedom[0] * scalar)
    rightBound = (relativeXY[0] >= 0 and relativeXY[0] < carFreedom[1] * scalar)
    if (leftBound or rightBound)
      car.attr('x', d.x = d3.event.x)
    else
      # TODO: Set min/max position instead of stopping
      console.log 'collision'
  else
    # TODO: Do calculations for Y
    car.attr('y', d.y = d3.event.y)

dragEnd = (d) ->
  console.log 'end'

drag = d3.behavior.drag()
  .origin (d) -> d
  .on('dragstart', dragStart)
  .on('drag', dragMove)
  .on('dragend', dragEnd)

# Calculate car freedom
detectFreedom = (car) ->
  console.log 'Determining freedom for car with position: ', car.attr('data-position'), car.attr('data-orientation'), carPositions(car)
  pos = car.attr('data-position')
  if car.attr('data-orientation') is 'horizontal'
    o = intersection(horizontalPositions(pos), occupiedPositions())
    upper = d3.min(o.filter (n) -> n > d3.max(carPositions(car)))
    lower = d3.max(o.filter (n) -> n < d3.min(carPositions(car)))
  else
    o = intersection(verticalPositions(pos), occupiedPositions())
    upper = d3.min(o.filter (n) -> n > d3.max(carPositions(car)))
    lower = d3.max(o.filter (n) -> n < d3.min(carPositions(car)))

  # Convert to relative freedom
  if car.attr('data-orientation') is 'horizontal'
    positions = horizontalPositions(pos)
  else
    positions = verticalPositions(pos)

  if upper
    u = positions.indexOf(upper) - positions.indexOf(d3.max(carPositions(car)))
  else
    u = board - positions.indexOf(d3.max(carPositions(car)))
  l = positions.indexOf(d3.min(carPositions(car))) - positions.indexOf(lower)
  return [l - 1, u - 1]

horizontalPositions = (position) ->
  d3.range(position - position % board, position - position % board + board)

verticalPositions = (position) ->
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
  if orientation is 'horizontal'
    return horizontalPositions(pos).slice(pos % board, pos % board + length)
  else
    start = Math.floor(pos/board)
    return verticalPositions(pos).slice(start, start + length)

positionToX = (position) ->
  scalar * (position % board) + carPadding
positionToY = (position) ->
  scalar * Math.floor(position/board) + carPadding

d3.json 'js/level1.json', (error, json) ->
  console.warn(error) if error

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
