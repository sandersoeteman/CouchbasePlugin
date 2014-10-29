window.couch = function(methodName, paramArray, fnSuccess, fnError, context) {
	context = context || window;

	if (typeof cordova === 'undefined' || !cordova.exec) {
		console.log('CORDOVA TEST CONFIG. Calling CouchDB with ' + paramArray); 
	}
	else {
		cordova.exec(
            function (result) {
            	if(fnSuccess) {
                	fnSuccess.call(context, result);
                }
            },
            function (err) { 
            	console.log('cordova error');
            	console.log(err);
            	if(fnError) {
                    fnError.call(context, err);
                }
            },
            'PlanbordCouch',
            methodName,
            paramArray
        );
	}
};
