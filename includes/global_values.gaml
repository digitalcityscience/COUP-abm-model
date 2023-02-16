/**
* Name: globalvalues
* Based on the internal empty template. 
* Author: andre
* Tags: 
*/


model globalvalues

/* Insert your model definition here */
global {
	string inputsFolder <- "/input_files"; 

	//Simulation speed equals real time
	float cycle_equals<-60.0; // in seconds
	float step <- cycle_equals#s; //simulation speed
	bool export_hotspots <- false;
	
	// global variables
	int leisure_prob <- 20; // 20 % of agents choose leisure activity
	int lunch_outside_prob <- 20; // 20 % of agents have lunch outside their workplace
	int coffee_after_lunch_prob <- 20; // 20% of agents have coffee after lunch (applied only to agents having lunch outside)
	int amenity_visitors_arriving_with_pt <- 40; // 40% of amenity visitor arrive by PT and do not live in the area
	
	init {
		starting_date <- date([current_date.year,current_date.month,current_date.day,8,0,0]);
	}
}
