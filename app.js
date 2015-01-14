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
  cookie: {
     httpOnly: false
   },
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

// Form routes
app.post('/step1', function (req, res) {
  var sess = req.session;
  sess.scores = {}
  sess.group = Math.round(Math.random())
  sess.vraag1 = req.body.vraag1;
  sess.vraag2 = req.body.vraag2;
  sess.vraag3 = req.body.vraag3;
  sess.name = 'Onbekend';
  if (req.body.name) { sess.name = req.body.name; }
  // TODO: Set experiment group
  console.log(sess.name, sess.vraag1, sess.vraag2, sess.vraag3);

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

  sess.identifier = components.join(".");
  res.redirect('/1')
})
app.post('/step2', function (req, res) {
  var sess = req.session;
  for(var z = 1; z <= 4; z++) {
    sess['vraag'+(z+3)] = req.body['vraag'+z];
  }
  res.redirect('/part3')
})
app.post('/step3', function (req, res) {
  var sess = req.session;
  for(var z = 1; z <= 9; z++) {
    sess['vraag'+(z+8)] = req.body['vraag'+z];
  }
  sess['vraag'+(5+3)] = req.body['vraagx']
  // Interim-save
  saveSurvey(req, sess, 17, 1);

  res.redirect('/5')
})
app.post('/step4', function (req, res) {
  var sess = req.session;
  var target = targetFromSess(sess);
  for(var z = 1; z <= 17; z++) {
    sess['vraag'+(z+17)] = req.body['vraag'+z];
  }

  saveSurvey(req, sess, 34, 2);
  res.redirect('/end')
});

function saveSurvey(req, sess, q, stage) {
  var user_agent = req.get('User-Agent');
  sheet.setAuth(config.google_username, config.google_password, function(err){
    var data = {
      stage: stage,
      identifier: sess.identifier,
      name: sess.name,
      UA: user_agent,
      IP: (req.headers['x-forwarded-for'] || req.connection.remoteAddress),
      stored: getDateTime(),
      group: sess.group,
      oefenscore: getPracticeScore(sess.scores),
      score: getRealScore(sess.scores),
      target: targetFromSess(sess)
    };
    for (var n = 1; n <= q; n++) {
      data['vraag'+n] = sess['vraag'+n];
    }
    sheet.addRow(1, data);
  });
}


// routes as normal
app.post('/store', function (req, res) {
  var json = req.body
  var sess=req.session;
  var name = sess.name;
  console.log(name, json)
  // Store scores to session
  if (json.hasOwnProperty('winner')) {
    sess.scores[json.winner.level] = json.winner.moves - json.winner.perfect;
  }

  var user_agent = req.get('User-Agent');
  sheet.setAuth(config.google_username, config.google_password, function(err){
    if (json.hasOwnProperty('winner')) {
      winner = json.winner;
      sheet.addRow(2, {
        identifier: winner.identifier,
        name: name,
        level: winner.level,
        moves: winner.moves,
        time: winner.time,
        UA: user_agent,
        IP: (req.headers['x-forwarded-for'] || req.connection.remoteAddress),
        stored: getDateTime()
      });
    }
    if (json.hasOwnProperty('move')) {
      move = json.move
      sheet.addRow(3, {
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

  res.send('Score opgeslagen, u kunt door naar het volgende level');
})

function getPracticeScore(scores) {
  var score = 0;
  for (var n = 2; n <= 4; n++) {
    if (scores[''+n]) { score += scores[''+n]; }
  }
  return score;
}
function getRealScore(scores) {
  var score = 0;
  for (var n = 5; n <= 10; n++) {
    if (scores[''+n]) { score += scores[''+n]; }
  }
  return score;
}

app.get('/score', function(req, res) {
  var sess = req.session;
  var score = getPracticeScore(sess.scores);
  res.send('' + score);
});

app.get('/score/:id', function(req, res) {
  var sess=req.session;
  var scores = sess.scores;
  var level = parseInt(req.params.id)
  var score = 0;
  if (scores[''+level]) { score += scores[''+level]; }
  res.send('+' + score);
});

function targetFromSess(sess) {
  var score = 0;
  if (sess.group == 1) {
    score = getTarget(getPracticeScore(sess.scores));
  } else {
    //res.send('' + sess.vraag8) // user defined score
    score = 51; // fixed target
  }
  return score;
}
app.get('/target', function(req, res) {
  var sess = req.session;
  res.send('' + targetFromSess(sess));
});

app.get('/group', function(req, res) {
  var sess = req.session;
  res.send('' + sess.group);
});
app.get('/info', function(req, res) {
  var sess = req.session;
  var globalScore = getRealScore(sess.scores);
  res.send('' + globalScore);
});

app.get('/:id', function (req, res) {
  var sess=req.session;
  var level = parseInt(req.params.id)
  var next_level = (level + 1).toString()
  res.render('../public/game', { identifier: sess.identifier, level: level.toString(), next_level: next_level });
});

function getTarget(score) {
  var table = [17, 18, 20, 21, 23, 24, 26, 28, 29, 31, 32, 34, 35, 37, 39, 40, 42, 43, 45, 46, 48, 50, 51, 53, 54, 56, 58, 59, 61, 62, 64, 65, 67, 69, 70, 72, 73, 75, 76, 78, 80, 81, 83, 84, 86, 88, 89, 91, 92, 94, 95, 97, 99, 100, 102, 103, 105, 106, 108, 110, 111];
  return table[score];
}
