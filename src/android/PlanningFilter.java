import java.util.List;
import java.util.Map;

import com.couchbase.lite.ReplicationFilter;
import com.couchbase.lite.SavedRevision;


public class PlanningFilter implements ReplicationFilter {

	@SuppressWarnings("unchecked")
	@Override
	public boolean filter(SavedRevision revision, Map<String, Object> params) {
		Integer gebruikerID = (Integer) params.get("GebruikerID");
		
		if(gebruikerID == -1) {
			return false;
		}
		

		String type = (String) params.get("type");
		if(!type.equals("activiteit")) {
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
