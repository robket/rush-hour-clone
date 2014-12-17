# Rush Hour Survey
Clone of the popular [Rush Hour](http://en.wikipedia.org/wiki/Rush_Hour_%28board_game%29) board game, with [D3.js](https://d3js.org) and [Harp](http://harpjs.com).

This branch features a version of the game used in a survey with Google Forms.

Add `config.js`
~~~javascript
var config = {}
config.spreadsheet_key = '<sheet-key>';
config.google_username = '<google-username>';
config.google_password = 'xxxxxxxx';
module.exports = config;
~~~

Now run
~~~bash
node survey.js
~~~
