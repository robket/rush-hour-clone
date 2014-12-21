var express = require("express");
var bodyParser = require('body-parser');
var harp = require("harp");
var GoogleSpreadsheet = require("google-spreadsheet");
var config = require('./config');
var sheet = new GoogleSpreadsheet(config.spreadsheet_key);
var app = express();

app.use(express.static(__dirname + "/public"));
app.use(harp.mount(__dirname + "/public"));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.set('view engine', 'jade');

app.listen(9000);
console.log("Survey listening at port 9000")

// routes as normal
app.post('/store', function (req, res) {
  var json = req.body
  console.log(json)

  var user_agent = req.get('User-Agent');
  sheet.setAuth(config.google_username, config.google_password, function(err){
    if (json.hasOwnProperty('winner')) {
      winner = json.winner
      sheet.addRow(1, {
        identifier: winner.identifier,
        level: move.level,
        moves: winner.moves,
        time: winner.time,
        UA: user_agent,
        IP: (req.headers['x-forwarded-for'] || req.connection.remoteAddress)
      });
    }
    if (json.hasOwnProperty('move')) {
      move = json.move
      sheet.addRow(2, {
        identifier: move.identifier,
        level: move.level,
        moves: move.moves,
        time: move.time,
        description: move.description,
        UA: user_agent,
        IP: (req.headers['x-forwarded-for'] || req.connection.remoteAddress)
      });
    }
  });

  res.send('Saved, thank you');
})

app.get('/', function(req, res) {
  res.redirect('/1')
})
app.get('/:id', function (req, res) {
  var date = new Date();
  var components = [
    date.getMilliseconds(),
    date.getSeconds(),
    date.getMinutes(),
    date.getHours(),
    date.getDate(),
    date.getMonth(),
    date.getYear()
  ];

  var id = components.join(".");
  if (req.query['id']) {
    id = req.query['id'];
  }
  var level = parseInt(req.params.id)
  var next_level = (level + 1).toString()
  res.render('../public/game', { identifier: id, level: level.toString(), next_level: next_level });
})
