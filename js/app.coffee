container = '#game'

svg = d3.select(container)
  .append('svg')
  .attr('width', '100%')
  .attr('height', '100%')

board = 6 # positions
scalar = 100 # px
tilePadding = 16
carPadding = 6

dragMove = (d) ->
  console.log d3.select(this)

drag = d3.behavior.drag()
  .origin (d) -> d
  .on('drag', dragMove)

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


  cars = svg.append('g')
    .attr('class', 'cars')
    .selectAll('rect.car')
    .data(json.cars)
    .enter()
    .append('rect')

  carAttributes = cars
    .attr 'class', 'car'
    .attr 'x', (d) -> scalar * (d.position % board) + carPadding
    .attr 'y', (d) -> scalar * Math.floor(d.position/board) + carPadding
    .attr 'height', (d) ->
      (if d.orientation is 'vertical'
        scalar * d.length
      else scalar) - carPadding * 2
    .attr 'width', (d) ->
      (if d.orientation is 'horizontal'
        scalar * d.length
      else scalar) - carPadding * 2
    .attr('fill', (d) -> if d.player then 'green' else 'pink' )
    .call(drag)
