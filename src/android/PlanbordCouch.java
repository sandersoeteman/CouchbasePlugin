package net.pictoplanner.plugin;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.AssetManager;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.CordovaInterface;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.couchbase.lite.android.AndroidContext;
import com.couchbase.lite.CouchbaseLiteException;
import com.couchbase.lite.Manager;
import com.couchbase.lite.Database;
import com.couchbase.lite.Mapper;
import com.couchbase.lite.Emitter;
import com.couchbase.lite.Reducer;
import com.couchbase.lite.View;
import com.couchbase.lite.listener.LiteListener;
import com.couchbase.lite.listener.Credentials;
import com.couchbase.lite.replicator.Replication;
import com.couchbase.lite.router.URLStreamHandlerFactory;
import com.couchbase.lite.util.Log;

import java.io.IOException;
import java.io.InputStream;
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
	private static final String TAG = "PlanbordCouch";
	private static final String USERNAME = "USERNAME";
	private static final String PASSWORD = "PASSWORD";
	private static final String COMPACTION_DATE = "COMPACTION_DATE";
	private Thread listenerThread = null;
	private LiteListener listener = null;
	private Manager manager = null;
	private Database dbApp = null;
	private Database dbPlanning = null;
	private Database dbImages = null;
	private Database dbUsers = null;
	private boolean initFailed = false;
    private Credentials allowedCredentials;

	/**
	 * Constructor.
	 */
	public PlanbordCouch() {
		super();
		System.out.println("PlanbordCouch() constructor called");
	}

	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		System.out.println("initialize() called");

		super.initialize(cordova, webView);
		initCBLite();
	}

	private void initCBLite() {
		try {
			Log.d(TAG, "1");
		    allowedCredentials = new Credentials();
			Log.d(TAG, "2");
			URLStreamHandlerFactory.registerSelfIgnoreError();
			Log.d(TAG, "3");
			manager = startCBLite(this.cordova.getActivity());
			Log.d(TAG, "4: " + manager.toString());
			dbUsers = manager.getDatabase("planbord_user");
			Log.d(TAG, "5: " + dbUsers.getName());
			dbApp = manager.getDatabase("app");
			Log.d(TAG, "6: " + dbApp.getName());
			startCBLListener(DEFAULT_LISTEN_PORT, manager, allowedCredentials);
			Log.d(TAG, "7: " + listener.getListenPort());
			// TODO CORS dingen hier implementeren??
			
			System.out.println("initCBLite() completed successfully");

		} catch (final Exception e) {
			e.printStackTrace();
			initFailed = true;
		}

	}


	protected Manager startCBLite(Context context) {
		Manager manager;
		try {
		    Manager.enableLogging(Log.TAG, Log.DEBUG);
			Manager.enableLogging(Log.TAG_SYNC, Log.ERROR);
			Manager.enableLogging(Log.TAG_QUERY, Log.VERBOSE);
			Manager.enableLogging(Log.TAG_VIEW, Log.ERROR);
			Manager.enableLogging(Log.TAG_CHANGE_TRACKER, Log.ERROR);
			Manager.enableLogging(Log.TAG_BLOB_STORE, Log.DEBUG);
			Manager.enableLogging(Log.TAG_DATABASE, Log.DEBUG);
			Manager.enableLogging(Log.TAG_LISTENER, Log.DEBUG);
			Manager.enableLogging(Log.TAG_MULTI_STREAM_WRITER, Log.ERROR);
			Manager.enableLogging(Log.TAG_REMOTE_REQUEST, Log.VERBOSE);
			Manager.enableLogging(Log.TAG_ROUTER, Log.DEBUG);
			manager = new Manager(new AndroidContext(context), Manager.DEFAULT_OPTIONS);
			
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
		return manager;
	}


	private void startCBLListener(int listenPort, Manager manager, Credentials allowedCredentials) {
		listener = new LiteListener(manager, listenPort, allowedCredentials);
		listenerThread = new Thread(listener);
		listenerThread.start();
	}


	private String setup() throws CouchbaseLiteException, IOException {
		
		View viewUsers = dbUsers.getView("planbord_user/allUsers");
		viewUsers.setMap(new Mapper() {
		    @Override
		    public void map(Map<String, Object> document, Emitter emitter) {
		    	String type = (String) document.get("type");
		    	if(type != null && type.equals("user")) {
		    		Integer gebruikerID = (Integer) document.get("GebruikerID");
		    		emitter.emit(gebruikerID, document);
		    	}
		    }
		}, Float.toString(VERSION));
		
		
		String address = "https://db.pictoplanner.net/android-app-test";
		URL url = new URL(address);
		
		Replication pull = dbApp.createPullReplication(url);
		pull.setContinuous(true);
		pull.start();
		
//		Database dbApp = manager.getExistingDatabase("app");
//		if(dbApp == null) {
//            AssetManager assets = this.cordova.getActivity().getAssets();
//            InputStream cannedDb = assets.open("app.cblite");
//            String attsFolder = "couchtalk attachments";
//            HashMap<String, InputStream> cannedAtts = new HashMap<String, InputStream>();
//            for (String attName : assets.list(attsFolder)) {
//                InputStream att = assets.open(String.format("%s/%s", attsFolder, attName));
//                cannedAtts.put(attName.toLowerCase(), att);
//            }
//            manager.replaceDatabase("app", cannedDb, cannedAtts);
//            
//            // HACK: intentionally may remain `null` so app crashes instead of silent trouble…
//            dbApp = manager.getExistingDatabase("app");
//		}
		
		View viewApp = dbApp.getView("app/allClients");
		viewApp.setMap(new Mapper() {
		    @Override
		    public void map(Map<String, Object> document, Emitter emitter) {
		    	String type = (String) document.get("type");
		    	if(type != null && type.equals("user")) {
		    		Integer gebruikerID = (Integer) document.get("GebruikerID");
		    		emitter.emit(gebruikerID, document);
		    	}
		    }
		}, Float.toString(VERSION));
		
		View viewVersionDoc = dbApp.getView("app/allVersionDocs");
		viewVersionDoc.setMap(new Mapper() {
		    @Override
		    public void map(Map<String, Object> document, Emitter emitter) {
		    	String type = (String) document.get("type");
		    	if(type != null && type.equals("version")) {
		    		String id = (String) document.get("_id");
		    		emitter.emit(id, document);
		    	}
		    }
		}, Float.toString(VERSION));
		
		return String.format(
				"http://%s:%s@localhost:%d/",
                allowedCredentials.getLogin(),
                allowedCredentials.getPassword(),
                listener.getListenPort()
        );
	}

	@Override
	public boolean execute(String action, JSONArray args,
			CallbackContext callback) {
		
		if (initFailed == true) {
			callback.error("Failed to initialize couchbase lite.  See console logs");
			return false;
		} else {
			if (action.equals("setup")) {
				try {
					String host = this.setup();

					JSONObject message = new JSONObject();
					message.put("version", Float.toString(VERSION));
					message.put("couchAddress", host);
					callback.success(message);

					return true;

				} catch (final Exception e) {
					e.printStackTrace();
					callback.error(e.getMessage());
				}
			}
			else if(action.equals("getUsername")) {
				String username = this.getUsername();
				callback.success(username);

				return true;
			}
			else if(action.equals("saveUserCredentials")) {
				try {
					this.saveUserCredentials(args.getString(0), args.getString(1));
					callback.success();
					
					return true;
				} catch (final Exception e) {
					e.printStackTrace();
					callback.error(e.getMessage());
				}
			}
			else if(action.equals("deleteAllAccounts")) {
				this.deleteAllAccounts();
				callback.success();

				return true;
			}
			else if(action.equals("setupUser")) {
				try {
					this.setupUser();
					callback.success();
					
					return true;
				} catch (final Exception e) {
					e.printStackTrace();
					callback.error(e.getMessage());
				}
			}
			else if(action.equals("setupReplicationForUser")) {
				try {
					this.setupReplicationForUser(args.getString(0), args.getString(1), args.getJSONArray(2), args.getJSONArray(3));
					callback.success();
					
					return true;
				} catch (final Exception e) {
					e.printStackTrace();
					callback.error(e.getMessage());
				}
			}
			else if(action.equals("stopReplications")) {
				try {
					this.stopReplications();
					callback.success();
					
					return true;
				} catch (final Exception e) {
					e.printStackTrace();
					callback.error(e.getMessage());
				}
			}
		}
		
		return false;
	}
	
	private void compact() throws CouchbaseLiteException, IOException {
		// clear time
		Date today = new Date();
		Calendar cal = Calendar.getInstance(); 
		cal.setTime(today);
		cal.set(Calendar.HOUR_OF_DAY, 0);
		cal.set(Calendar.MINUTE, 0);
		cal.set(Calendar.SECOND, 0);
		cal.set(Calendar.MILLISECOND, 0);
		today = cal.getTime();
		
		Date lastDate = this.getLastCompactionDate();
		
		if(lastDate == null || today.after(lastDate)) {
			List<String> dbNames = manager.getAllDatabaseNames();
			if(dbNames != null && dbNames.size() > 0) {
				for(String dbName : dbNames) {
					Database db = manager.getDatabase(dbName);
					db.compact();
				}
			}
			
			this.setLastCompactionDate(today);
		}
	}
	
	private void startReplications() throws CouchbaseLiteException, IOException {
		List<String> dbNames = manager.getAllDatabaseNames();
		if(dbNames != null && dbNames.size() > 0) {
			for(String dbName : dbNames) {
				Database db = manager.getDatabase(dbName);
				
				List<Replication> replications = db.getAllReplications();
				if(replications != null && replications.size() > 0) {
					for(Replication repl : replications) {
						repl.stop();
					}
				}
			}
		}		
	}
	
	private void stopReplications() throws CouchbaseLiteException, IOException {
		List<String> dbNames = manager.getAllDatabaseNames();
		if(dbNames != null && dbNames.size() > 0) {
			for(String dbName : dbNames) {
				Database db = manager.getDatabase(dbName);
				
				List<Replication> replications = db.getAllReplications();
				if(replications != null && replications.size() > 0) {
					for(Replication repl : replications) {
						repl.stop();
					}
				}
			}
		}
	}
	
	private void setupReplicationForUser(String username, String server, JSONArray planningDBs, JSONArray imageDBs) throws Exception {
		String myUsername = this.getUsername();
		String password = this.getPassword();
		
		if(username == null || username.isEmpty() || myUsername == null || myUsername.isEmpty() || !username.equals(myUsername)) {
			throw new Exception("Username mismatch for replication");
		}
		
		Integer gebruikerID = Integer.parseInt(username);
		
		String planningDBName = String.format("planning_%s", username);
		String imagesDBName = String.format("images_%s", username);
		
		Database dbPlanning = manager.getDatabase(planningDBName);
		Database dbImages = manager.getDatabase(imagesDBName);
		
		String[] split = server.split("://");
		if(split == null || split.length != 2) {
			throw new Exception("remote server address incomplete");
		}
		
		String scheme = split[0];
		String hostname = split[1];
		Map<String, Object> filterParams = new HashMap<String, Object>();
		filterParams.put("GebruikerID", gebruikerID);
		
		if(imageDBs.length() > 0) {
			for(int i=0; i< imageDBs.length(); i++) {
				String db = imageDBs.getString(i);
				String address = String.format("%s://%s:%s@%s/%s", scheme, username, password, hostname, db);
				URL url = new URL(address);
				
				Replication pull = dbImages.createPullReplication(url);
				pull.setContinuous(true);
				pull.start();
				
				if(db.equals(imagesDBName)) {
					Replication push = dbImages.createPushReplication(url);
					push.setContinuous(true);
					push.setFilter("images/imageFilter");
					push.setFilterParams(filterParams);
					push.start();
				}
			}
		}
		
		if(planningDBs.length() > 0) {
			for(int i=0; i< planningDBs.length(); i++) {
				String db = planningDBs.getString(i);
				String address = String.format("%s://%s:%s@%s/%s", scheme, username, password, hostname, db);
				URL url = new URL(address);
				
				Replication pull = dbPlanning.createPullReplication(url);
				pull.setContinuous(true);
				pull.start();
				
				if(db.equals(planningDBName)) {
					Replication push = dbPlanning.createPushReplication(url);
					push.setContinuous(true);
					push.setFilter("planning/planningFilter");
					push.setFilterParams(filterParams);
					push.start();
				}
			}
		}
	}

	private String setupUser() throws IOException, CouchbaseLiteException {
		String username = this.getUsername();
		
		String planningDBName = String.format("planning_%s", username);
		String imagesDBName = String.format("images_%s", username);
		
		dbImages = manager.getDatabase(imagesDBName);
		
		// imagesFilter
		dbImages.setFilter("images/imageFilter", new ImagesFilter());
		
		// imagesByTag
		View viewImagesByTag = dbImages.getView("images/imagesByTag");
		viewImagesByTag.setMapReduce(new Mapper() {
		    @Override
		    public void map(Map<String, Object> document, Emitter emitter) {
		    	String type = (String) document.get("type");
		    	if(type != null && type.equals("image")) {
					@SuppressWarnings("unchecked")
					List<String> tags = (List<String>) document.get("Tags");
					if(tags != null && tags.size() > 0) {
						for(String tag : tags) {
							String[] strArr = { tag };
				    		emitter.emit(strArr, 1);		
						}
					}
		    	}
		    }
		}, new Reducer() {
		    @Override
		    public Object reduce(List<Object> keys, List<Object> values, boolean rereduce) {
		       return View.totalValues(values);
		    }
		}, Float.toString(VERSION));
		
		// allImages
		View viewAllImages = dbImages.getView("images/allImages");
		viewAllImages.setMap(new Mapper() {
		    @Override
		    public void map(Map<String, Object> document, Emitter emitter) {
		    	String type = (String) document.get("type");
		    	if(type != null && type.equals("image")) {
		    		String id = (String) document.get("_id");
					String[] strArr = { id };
		    		emitter.emit(strArr, null);		
		    	}
		    }
		}, Float.toString(VERSION));
		
		
		
		// PLANNING
		dbPlanning = manager.getDatabase(planningDBName);
		
		// planningFilter
		dbPlanning.setFilter("planning/planningFilter", new PlanningFilter());

		// allActiviteiten
		View viewAllActiviteiten = dbPlanning.getView("planning/allActiviteiten");
		viewAllActiviteiten.setMap(new Mapper() {
		    @Override
		    public void map(Map<String, Object> document, Emitter emitter) {
		    	String type = (String) document.get("type");
		    	if(type != null && type.equals("activiteit")) {
		    		String id = (String) document.get("_id");
		    		emitter.emit(id, document);		
		    	}
		    }
		}, Float.toString(VERSION));
		
		View viewActiviteitenByDate = dbPlanning.getView("planning/activiteitenByDate");
		viewActiviteitenByDate.setMap(new Mapper() {
		    @Override
		    public void map(Map<String, Object> document, Emitter emitter) {
		    	String type = (String) document.get("type");
		    	if(type != null && type.equals("activiteit")) {
		    		String[] dates = new String[0];
					try {
						dates = this.GetActivityDatesForDoc(document);
					} catch (ParseException e1) {
						e1.printStackTrace();
						return;
					}
		    		String lastDatumStr = null;
		    		for(String date : dates) {
		    			lastDatumStr = date;
		    			String[] strArr = { date };
		    			emitter.emit(strArr, null);
		    		}
		    		
		    		// emit de laatste datum waarop we deze activiteit berekend hebben.
		    		// Bij notifications berekenen bekijken of dit nog binnen de horizon ligt
		    		// herberekenen van de planning als voor alle documenten waarvoor geldt: "planningshorizon < vandaag + 1 jaar"
		    		String recurringType = (String) document.get("RecurringType");
		    		if(lastDatumStr != null && !recurringType.equals("Geen_herhaling")) {
		    			DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
		    			String recurringEndDateString = (String) document.get("RecurringEndDate");
		    			Date recurringEndDate = null;
		    			Date lastDate = null;
		    			
		    			if(recurringEndDateString != null && recurringEndDateString.length() != 0) {
		    				try {
								recurringEndDate = format.parse(recurringEndDateString);
							} catch (ParseException e) {
								e.printStackTrace();
							}	
		    			}
		    			
		    			if(lastDatumStr != null && lastDatumStr.length() != 0) {
			    			try {
								lastDate = format.parse(lastDatumStr);
							} catch (ParseException e) {
								e.printStackTrace();
							}
		    			}
		    			
		    			if(recurringEndDate != null) {
		    				Calendar c = Calendar.getInstance();
		    				c.setTime(recurringEndDate); 
		    				c.add(Calendar.DATE, -2); // Adding 5 days
		    				recurringEndDate = c.getTime();
		    			}
		    			
		    			if(recurringEndDate == null || (lastDate != null && recurringEndDate.after(lastDate))) {
		    				String[] emitArr = { "planningshorizon", lastDatumStr };
		    				emitter.emit(emitArr, null);
		    			}
		    		}
		    	}
		    }

			private String[] GetActivityDatesForDoc(
					Map<String, Object> document) throws ParseException {
				String type = (String) document.get("type");
		    	if(type != null && type.equals("activiteit")) {
		    		String recurringType = (String) document.get("RecurringType");
		    		if(recurringType.equals("Geen_herhaling")) {
		    			String[] dates = { (String)document.get("Datum") }; 
		    			return dates;
		    		}
		    		else if(recurringType.equals("Dagelijks")) {
		    			return this.GetDailyActivitiesForDoc(document);
		    		}
		    		else if(recurringType.equals("Wekelijks")) {
		    			return this.GetWeeklyActivitiesForDoc(document);
		    		}
		    		else if(recurringType.equals("Maandelijks")) {
		    			return this.GetMonthlyActivitiesForDoc(document);
		    		}
		    		else if(recurringType.equals("Jaarlijks")) {
		    			return this.GetYearlyActivitiesForDoc(document);
		    		}
		    	}
		    	return new String[0];
			}

			@SuppressWarnings("unchecked")
			private String[] GetYearlyActivitiesForDoc(
					Map<String, Object> document) throws ParseException {
				List<String> dates = new ArrayList<String>();
				DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
				Date docDate = null;
				Date leftExtent = this.GetLeftExtent(document);
				Date rightExtent = this.GetRightExtent(document);
				
				try {
					docDate = format.parse((String) document.get("Datum"));
				} catch (ParseException e) {
					e.printStackTrace();
					return null;
				}
				
				Map<String, Object> recurringPattern = (Map<String, Object>) document.get("RecurringPattern");
				
				if(docDate != null && recurringPattern != null) {
					Integer perN = (Integer) recurringPattern.get("per_n");
					
					Calendar c = Calendar.getInstance();
					c.setTime(docDate); 
					int dayOfMonth = c.get(Calendar.DATE);
					c.set(Calendar.DATE, 1);
					Date yearDate = c.getTime();
					
					if(leftExtent.before(rightExtent) && perN != null) {
						do {
							Integer daysInMonth = c.getActualMaximum(Calendar.DAY_OF_MONTH);
							
							if(dayOfMonth <= daysInMonth) {
			    				c.setTime(yearDate); 
			    				c.set(Calendar.DATE, dayOfMonth);
								Date date = c.getTime();
								
								if(!this.IsIgnoredDate(date, document) && (date.after(leftExtent) || date.equals(leftExtent)) && (date.before(rightExtent) || date.equals(rightExtent))) {
									dates.add(format.format(date));
								}
							}
							
		    				c.setTime(yearDate); 
		    				c.add(Calendar.YEAR, perN);
		    				yearDate = c.getTime();
						} while(yearDate.before(rightExtent) || yearDate.equals(rightExtent));
					}
				}

				return (String[]) dates.toArray(new String[dates.size()]);
			}

			@SuppressWarnings("unchecked")
			private String[] GetMonthlyActivitiesForDoc(
					Map<String, Object> document) throws ParseException {
				List<String> dates = new ArrayList<String>();
				DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
				Date docDate = null;
				Date leftExtent = this.GetLeftExtent(document);
				Date rightExtent = this.GetRightExtent(document);
				
				try {
					docDate = format.parse((String) document.get("Datum"));
				} catch (ParseException e) {
					e.printStackTrace();
					return null;
				}
				
				Map<String, Object> recurringPattern = (Map<String, Object>) document.get("RecurringPattern");
				
				if(docDate != null && recurringPattern != null) {
					Integer perN = (Integer) recurringPattern.get("per_n");
					
					Calendar c = Calendar.getInstance();
					c.setTime(docDate); 
					int dayOfMonth = c.get(Calendar.DATE);
					c.set(Calendar.DATE, 1);
					Date monthDate = c.getTime();
					
					if(leftExtent.before(rightExtent) && perN != null) {
						do {
							Integer daysInMonth = c.getActualMaximum(Calendar.DAY_OF_MONTH);
							
							if(dayOfMonth <= daysInMonth) {
			    				c.setTime(monthDate); 
			    				c.set(Calendar.DATE, dayOfMonth);
								Date date = c.getTime();
								
								if(!this.IsIgnoredDate(date, document) && (date.after(leftExtent) || date.equals(leftExtent)) && (date.before(rightExtent) || date.equals(rightExtent))) {
									dates.add(format.format(date));
								}
							}
							
		    				c.setTime(monthDate); 
		    				c.add(Calendar.MONTH, perN);
		    				monthDate = c.getTime();
						} while(monthDate.before(rightExtent) || monthDate.equals(rightExtent));
					}
				}

				return (String[]) dates.toArray(new String[dates.size()]);
			}

			@SuppressWarnings("unchecked")
			private String[] GetWeeklyActivitiesForDoc(
					Map<String, Object> document) throws ParseException {
				List<String> dates = new ArrayList<String>();
				DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
				Date docDate = null;
				Date leftExtent = this.GetLeftExtent(document);
				Date rightExtent = this.GetRightExtent(document);
				List<Integer> dagen = new ArrayList<Integer>();
				
				try {
					docDate = format.parse((String) document.get("Datum"));
				} catch (ParseException e) {
					e.printStackTrace();
					return null;
				}
				
				Map<String, Object> recurringPattern = (Map<String, Object>) document.get("RecurringPattern");
				
				if(docDate != null && recurringPattern != null) {
					Integer perN = (Integer) recurringPattern.get("per_n");
					
					if((Boolean) recurringPattern.get("zo")) {
						dagen.add(1);
					}
					if((Boolean) recurringPattern.get("ma")) {
						dagen.add(2);
					}
					if((Boolean) recurringPattern.get("di")) {
						dagen.add(3);
					}
					if((Boolean) recurringPattern.get("wo")) {
						dagen.add(4);
					}
					if((Boolean) recurringPattern.get("don")) {
						dagen.add(5);
					}
					if((Boolean) recurringPattern.get("vr")) {
						dagen.add(6);
					}
					if((Boolean) recurringPattern.get("za")) {
						dagen.add(7);
					}
					
					Calendar c = Calendar.getInstance();
					c.setTime(docDate); 
					int dayOfweek = c.get(Calendar.DAY_OF_WEEK);
					Date weekDate = (Date) docDate.clone();
					
					if(leftExtent.before(rightExtent) && perN != null) {
						do {
							
							for(Integer dag : dagen) {
								c.setTime(weekDate); 
			    				c.add(Calendar.DATE, dag - dayOfweek);
								Date date = c.getTime();
								
								if(!this.IsIgnoredDate(date, document) && (date.after(leftExtent) || date.equals(leftExtent)) && (date.before(rightExtent) || date.equals(rightExtent))) {
									dates.add(format.format(date));
								}
							}
							
		    				c.setTime(weekDate); 
		    				c.add(Calendar.DATE, perN * 7);
		    				weekDate = c.getTime();
						} while(weekDate.before(rightExtent) || weekDate.equals(rightExtent));
					}
				}
				
				return (String[]) dates.toArray(new String[dates.size()]);
			}

			@SuppressWarnings("unchecked")
			private String[] GetDailyActivitiesForDoc(
					Map<String, Object> document) throws ParseException {
				List<String> dates = new ArrayList<String>();
				DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
				Date docDate = null;
				Date leftExtent = this.GetLeftExtent(document);
				Date rightExtent = this.GetRightExtent(document);
				Integer perN = null;
				
				try {
					docDate = format.parse((String) document.get("Datum"));
				} catch (ParseException e) {
					e.printStackTrace();
					return null;
				}
				
				Map<String, Object> recurringPattern = (Map<String, Object>) document.get("RecurringPattern");
				
				if(docDate != null && recurringPattern != null) {
					perN = (Integer) recurringPattern.get("per_n");
					Date date = (Date) docDate.clone();
					Calendar c = Calendar.getInstance();
					
					if(leftExtent.before(rightExtent) && perN != null) {
						do {
							if(!this.IsIgnoredDate(date, document) && (date.after(leftExtent) || date.equals(leftExtent)) && (date.before(rightExtent) || date.equals(rightExtent))) {
								dates.add(format.format(date));
							}
							
		    				c.setTime(date); 
		    				c.add(Calendar.DATE, perN);
		    				date = c.getTime();
						} while(date.before(rightExtent) || date.equals(rightExtent));
					}
				}
				
				return (String[]) dates.toArray(new String[dates.size()]);
			}

			@SuppressWarnings("unchecked")
			private boolean IsIgnoredDate(Date date,
					Map<String, Object> document) {
				ArrayList<Map<String, Object>> ignoredDates = (ArrayList<Map<String, Object>>) document.get("DatesToIgnore");
				
				if(ignoredDates == null || ignoredDates.size() == 0) {
					return false;
				}
				
				DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
				String dateStr = format.format(date);
				for(Map<String, Object> item : ignoredDates) {
					String docDate = (String) item.get("Datum");
					if(dateStr.equals(docDate)) {
						return true;
					}
				}
				
				return false;
			}

			private Date GetRightExtent(Map<String, Object> document) throws ParseException {
				DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
				Calendar c = Calendar.getInstance();
				
				String recurringEndDateString = (String) document.get("RecurringEndDate");
    			Date recurringEndDate = null;
    			Date docDate = format.parse((String) document.get("Datum"));
				Date rightExtent = null;
				
				String recurringType = (String) document.get("RecurringType");
	    		if(recurringType.equals("Geen_herhaling")) {
	    			rightExtent = (Date) docDate.clone(); 
	    		}
	    		else {
	    			c.setTime(docDate); 
    				c.add(Calendar.DATE, RIGHT_EXTENT_PERIOD);
    				rightExtent = c.getTime();
	    		}
	    		
	    		if(recurringEndDateString == null || recurringEndDateString.isEmpty()) {
	    			return rightExtent;
	    		}
	    		
	    		try {
	    			recurringEndDate = format.parse(recurringEndDateString);
	    		}
	    		catch(ParseException e) {
	    			return rightExtent;
	    		}
	    		
	    		return rightExtent.before(recurringEndDate) ? rightExtent : recurringEndDate;
			}

			private Date GetLeftExtent(Map<String, Object> document) throws ParseException {
				DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
				Date docDate = format.parse((String) document.get("Datum"));
				Date leftExtent = null;
				Calendar c = Calendar.getInstance();
				
				String recurringType = (String) document.get("RecurringType");
	    		if(recurringType.equals("Geen_herhaling")) {
	    			leftExtent = (Date) docDate.clone(); 
	    		}
	    		else {
	    			c.setTime(docDate); 
    				c.add(Calendar.DATE, -LEFT_EXTENT_PERIOD);
	    			leftExtent = c.getTime();
	    		}
	    		
	    		return docDate.after(leftExtent) ? docDate : leftExtent;
			}
		}, Float.toString(VERSION));
				
		return null;
	}

	private void deleteAllAccounts() {
		SharedPreferences prefs = this.cordova.getActivity().getPreferences(Context.MODE_PRIVATE);
		SharedPreferences.Editor editor = prefs.edit();
	    editor.remove(USERNAME);
	    editor.remove(PASSWORD);

	    editor.commit();
	}

	private void saveUserCredentials(String username, String password) {
		SharedPreferences prefs = this.cordova.getActivity().getPreferences(Context.MODE_PRIVATE);
		SharedPreferences.Editor editor = prefs.edit();
	    editor.putString(USERNAME, username);
	    editor.putString(PASSWORD, password);

	    editor.commit();
	}

	private String getUsername() {
		SharedPreferences prefs = this.cordova.getActivity().getPreferences(Context.MODE_PRIVATE);
		return prefs.getString(USERNAME, "");
	}
	
	private String getPassword() {
		SharedPreferences prefs = this.cordova.getActivity().getPreferences(Context.MODE_PRIVATE);
		return prefs.getString(PASSWORD, "");
	}
	
	private Date getLastCompactionDate() {
		SharedPreferences prefs = this.cordova.getActivity().getPreferences(Context.MODE_PRIVATE);
		String dateStr = prefs.getString(COMPACTION_DATE, "");
		if(dateStr == null || dateStr.isEmpty()) {
			return null;
		}
		DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
		
		try {
			return format.parse(dateStr);
		}
		catch(final Exception e) {
			return null;
		}
	}
	
	private void setLastCompactionDate(Date date) {
		SharedPreferences prefs = this.cordova.getActivity().getPreferences(Context.MODE_PRIVATE);
		DateFormat format = new SimpleDateFormat("yyyy-MM-dd");
		SharedPreferences.Editor editor = prefs.edit();

		editor.putString(COMPACTION_DATE, format.format(date));
	    editor.commit();
	}


	public void onResume(boolean multitasking) {
		System.out.println("CBLite.onResume() called");
		try {
			this.startReplications();
		}
		catch(final Exception e) {
			
		}
	}

	

	public void onPause(boolean multitasking) {
		System.out.println("CBLite.onPause() called");
		try {
			this.stopReplications();
			this.compact();
		}
		catch(final Exception e) {
			
		}
	}
	
}
