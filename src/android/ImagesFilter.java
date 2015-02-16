package org.apache.cordova.plugin;

import java.util.List;
import java.util.Map;

import com.couchbase.lite.ReplicationFilter;
import com.couchbase.lite.SavedRevision;


public class ImagesFilter implements ReplicationFilter {

	@SuppressWarnings("unchecked")
	@Override
	public boolean filter(SavedRevision revision, Map<String, Object> params) {
		Integer gebruikerID = (Integer) params.get("GebruikerID");
		String type = (String) params.get("type");
		
		if(gebruikerID == -1) {
			return false;
		}
		
		if(!(type.equals("image") || type.equals("user_image"))) {
			return false;
		}
		
		List<String> gebruikers = (List<String>) params.get("Gebruikers");
		
		if(gebruikers == null || gebruikers.size() == 0) {
			return false;
		}
		
		if(gebruikers.contains(gebruikerID)) {
			return true;
		}
		
		return false;
	}

}
