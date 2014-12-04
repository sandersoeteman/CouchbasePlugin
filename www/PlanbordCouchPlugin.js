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
                        console.log('cordova error: ' err);
                        reject(new Error(err));
                    },
                    'PlanbordCouch',
                    methodName,
                    paramArray
                );
            }
        });
    }
}
