module.exports = {
    callMethod: function(methodName, paramArray) {
        return new Promise(function(resolve, reject) {

            if (typeof cordova === 'undefined' || !cordova.exec) {
                reject(Error('Cordova undefined')); 
            }
            else {
                cordova.exec (
                    function (result) {
                        resolve(result);
                    },
                    function (err) { 
                        reject(Error(err));
                    },
                    'PlanbordCouch',
                    methodName,
                    paramArray
                );
            }
        });
    }
}
