/**
* Name: pedestriannetwork
* Based on the internal empty template. 
* Author: andre
* Tags: 
*/


model amenityschedules

import "global_values.gaml"

/* Insert your model definition here */
global {
	
	csv_file amenity_times <- csv_file((inputsFolder + "/" + "agents/" + "Time_amenities_special.tsv"),true);
	species amenity_schedules{
		float hour;
		float university;
		float highschool;
		float school;
		float creative_space;
		float event_space;
		float museum;
		float library;
		float religious;
		float health_center;
		float community_center;
		float kita;
		float sports_facility;
		float toilet;
		float praxis_specialist;
		float praxis_general;
	}
	
		init {
		create amenity_schedules from:amenity_times with:[
			hour:float(read("Hour")),
			university:float(read("university")),
			highschool:float(read("highSchool")),
			school:float(read("elementarySchool")),
			creative_space:float(read("creativeSpace")),
			event_space:float(read("eventSpace")),
			museum:float(read("museum")),
			library:float(read("library")),
			religious:float(read("religiousUse")),
			health_center:float(read("healthCenter")),
			community_center:float(read("communityCenter")),
			kita:float(read("daycare [SK]")),
			sports_facility:float(read("sportsFacility")),
			toilet:float(read("toiletPublic")),
			praxis_specialist:float(read("medicalPractice")),
			praxis_general:float(read("generalMedPractice"))
		];
	}
}


