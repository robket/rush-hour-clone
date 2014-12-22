var express = require("express");
var session = require('express-session');
var bodyParser = require('body-parser');
var harp = require("harp");
var GoogleSpreadsheet = require("google-spreadsheet");
var config = require('./config');
var sheet = new GoogleSpreadsheet(config.spreadsheet_key);
var app = express();

app.use(session({
  secret: config.secret,
  resave: false,
  saveUninitialized: true
}));
app.use(express.static(__dirname + "/public"));
app.use(harp.mount(__dirname + "/public"));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.set('view engine', 'jade');

app.listen(9000);
console.log("Survey listening at port 9000")

function getDateTime() {
  var date = new Date();
  var hour = date.getHours();
  hour = (hour < 10 ? "0" : "") + hour;
  var min  = date.getMinutes();
  min = (min < 10 ? "0" : "") + min;
  var sec  = date.getSeconds();
  sec = (sec < 10 ? "0" : "") + sec;
  var year = date.getFullYear();
  var month = date.getMonth() + 1;
  month = (month < 10 ? "0" : "") + month;
  var day  = date.getDate();
  day = (day < 10 ? "0" : "") + day;
  return year + ":" + month + ":" + day + ":" + hour + ":" + min + ":" + sec;
}

// routes as normal
app.post('/start', function (req, res) {
  var sess=req.session;
  sess.name = req.body.name;
  res.redirect('/1')
})
app.post('/store', function (req, res) {
  var json = req.body
  var sess=req.session;
  var name = 'Onbekend';
  if (sess.name) { name = sess.name; }
  console.log(name, json)

  var user_agent = req.get('User-Agent');
  sheet.setAuth(config.google_username, config.google_password, function(err){
    if (json.hasOwnProperty('winner')) {
      winner = json.winner
      sheet.addRow(1, {
        identifier: winner.identifier,
        name: name,
        level: move.level,
        moves: winner.moves,
        time: winner.time,
        UA: user_agent,
        IP: (req.headers['x-forwarded-for'] || req.connection.remoteAddress),
        stored: getDateTime()
      });
    }
    if (json.hasOwnProperty('move')) {
      move = json.move
      sheet.addRow(2, {
        identifier: move.identifier,
        name: name,
        level: move.level,
        moves: move.moves,
        time: move.time,
        description: move.description,
        UA: user_agent,
        IP: (req.headers['x-forwarded-for'] || req.connection.remoteAddress),
        stored: getDateTime()
      });
    }
  });

  res.send('Saved, thank you');
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
