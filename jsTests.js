#!/usr/bin/nodejs

// with nodejs, argv begins with executable, then 
// executed script, then the arguments passed with the 
// script. So first argv is (3,4)

// so call currently is
// ./jsTests.js glucose.json clock.json

var now = new Date();
console.log(now)
var timeZone = now.toString().match(/([-\+][0-9]+)\s/)[1];

console.log('date is: '+ now);
console.log('t zone is:' + timeZone);





if (!module.parent) {
    var glucose_input = process.argv.slice(2, 3)
    var clock_input = process.argv.slice(3, 4);
    console.log('clock is: ' + clock_input);
    console.log('glucose is: ' + glucose_input);
    //var two = process.argv.slice(2, 3);
    //console.log('two is: ' + two);

    if (!glucose_input) { 
      console.log('usage: ', process.argv.slice(0,2), '<glucose.json>');
      process.exit(1);
     }

    var cwd = process.cwd();
    var glucose_data = require(cwd + '/' + glucose_input);
    glucose_data.reverse();
    len = glucose_data.length;


    console.log('len: ' + len );
    var bgnow = glucose_data[0].glucose;
    var bgOneBack = glucose_data[1].glucose;
    var delta = bgnow - bgOneBack;
    console.log('bgnow is: ' + bgnow);
    console.log('bgOneBack is: ' + bgOneBack);
    console.log('delta is: ' + delta);
    console.log(JSON.stringify(bgnow));
}

