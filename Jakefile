desc('Check and install required packages');
task('depends', [], function () {
    var npm = require('npm'), cb_counter = 0, wait_for_all = function () {
        if (--cb_counter === 0) complete();
    };
    var fs = require('fs');
    npm.load({}, function (err) {
        if (err) throw err;
        npm.commands.ls(['installed'], true, function (err, packages) {
            var file = fs.readFileSync('config/requirements.json'),
                requirements = JSON.parse(file);
            requirements.forEach(function (package) {
                cb_counter += 1;
                if (packages[package]) {
                    console.log('Package ' + package +
                      ' is already installed');
                    wait_for_all();
                } else {
                    npm.commands.install([package], wait_for_all);
                }
            });
        });
    });
}, true);