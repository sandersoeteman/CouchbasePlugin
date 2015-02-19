package org.apache.cordova.plugin.pictoplanner;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.SharedPreferences;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CordovaInterface;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.net.URL;
import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@SuppressLint("SimpleDateFormat")
public class PlanbordCouch extends CordovaPlugin {

	private static final int DEFAULT_LISTEN_PORT = 5984;
	private static final int LEFT_EXTENT_PERIOD = 60;
	private static final int RIGHT_EXTENT_PERIOD = 540;
	private static final float VERSION = 1.10f;
	private static final String USERNAME = "USERNAME";
	private static final String PASSWORD = "PASSWORD";
	private static final String COMPACTION_DATE = "COMPACTION_DATE";

	/**
	 * Constructor.
	 */
	public PlanbordCouch() {
		super();
		System.out.println("PlanbordCouch() constructor called");
	}

	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
	    super.initialize(cordova, webView);
	    // your init code here
	}



	@Override
	public boolean execute(String action, JSONArray args,
			CallbackContext callback) {
		
		callback.success("dit dan weer wel");
		
		return true;
	}
	
	
	


}
