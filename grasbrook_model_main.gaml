/***
* Name: Grasbrook
* Author: lopezbaeza
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model GB


import "includes/buildings.gaml"
import "includes/people.gaml"

global {
	
	// PLEASE NAME ALL YOUR SUB_SPECIES HERE:	
	list agent_species <- [people_resident, people_visitor, amenity_person];
	
	file boundary <- geojson_file(inputsFolder + "/" +  "bounds.geojson","EPSG:4326");
	geometry shape <- envelope(boundary); //Rectangle representing the extent of the simulation

	/// Streets | Pedestrian paths
	file<geometry> pedestrian_paths <- geojson_file(inputsFolder + "/" + "streets.geojson","EPSG:4326"); //QGIS Draw network and (Processing Toolbox:split with lines)
	graph network_pedestrian_path; //Street pedestrian network
	
	/// Amenities
	file amenities_geojson <- geojson_file(inputsFolder + "/" + "amenities.geojson","EPSG:4326"); 
	
	/// Agents definition
	csv_file aggregated_stats <- csv_file((inputsFolder + "/" + "agents/" + "Aggregated_stats.tsv"),true);
	
	list<int> main_functions;
	

	init { 
		//Initialization block: how the simulation starts
		create buildings from: amenities_geojson with:[
			id:string(read("city_scope_id")),
			main_function:int(read("GFK")),
			secondary_function:int(read("WGF")),
			stories:int(read("AOG")),
			stories_under:int(read("AUG")),
			area:int(read("GRF"))
		];
		create statistics from:aggregated_stats with:[
			Age:string(read("Age")),
			Percent_Age:int(read("Percent_Age")),
			Home:string(read("Home")),
			Percent_Home:int(read("Percent_Home")),
			Work_School:string(read("Work_School")),
			Percent_Work:int(read("Percent_Work")),
			lunch:string(read("lunch")),
			Percent_lunch:int(read("Percent_lunch")),
			Transport_mode_residents:string(read("Transport_mode_residents")),
			Percent_Transport_mode_residents:int(read("Percent_Transport_mode_residents")),
			Transport_mode_visitors:string(read("Transport_mode_visitors")),
			Percent_Transport_mode_visitors:int(read("Percent_Transport_mode_visitors"))
		];
	}
	
	reflex clock when: every(1#h) {
		
		write "time:" ; write current_date.hour;
		
		write "people_resident " + length(people_resident);
	    write "people_visitor " + length(people_visitor);
		write "amenity_person " + length(amenity_person);
		
	
	}


		reflex debug when:every(1#h) {
		

		write "buildings with visitors";
		write length(buildings where (each.nb_visitors > 0));

		list<string> states <- [
		"university",
		"highschool",
		"creative_space",
		"event_space",
		"museum",
		"library",
		"religious",
		"health_center",
		"community_center",
		"residential",
		"kita",
		"sports_facility",
		"toilet",
		"praxis_specialist",
		"praxis_general"

		] ;
		
		loop state over: states {
			list<buildings> buildings_with_state <- buildings where (each.state = state);
			int count <- length(buildings_with_state);
			if (count > 0) {
				write "****";
				write state;
				write string(count) + " active buildings";
				write "number of agents for this state " +  length(amenity_person where (each.my_amenity.state = state));
			}
			
			
		}
	
	}

	
			
	//Measurement indexes are updated every cycle
	int nb_people;
	float visitors_car;
	float visitors_public_trans;
	
	reflex update_leisure_prob when: every(1#h) {
		if current_date.hour >= 17 and leisure_prob > 0 {
			leisure_prob <- leisure_prob - 5;
		}
	}
	
	reflex update_amounts when: every(1#mn){
		// write "amount of visitors alive";  // @JESUS is normally around 20. Intended that way?
		// write length(people_visitor);
		
		nb_people <- length(agents of_generic_species people);
					
		visitors_public_trans<-((
			buildings sum_of (each.nb_workers))-((buildings sum_of (each.nb_residents))*((statistics where (each.Work_School = "inside") sum_of (each.Percent_Work))/100)))*
			((statistics where (each.Transport_mode_visitors = "public_transport_ubahn" or each.Transport_mode_visitors = "public_transport_other") sum_of (each.Percent_Transport_mode_visitors))/100);
		visitors_car<-((
			buildings sum_of (each.nb_workers))-((buildings sum_of (each.nb_residents))*((statistics where (each.Work_School = "inside") sum_of (each.Percent_Work))/100)))*
			((statistics where (each.Transport_mode_visitors = "MIV") sum_of (each.Percent_Transport_mode_visitors))/100);
	}
	
	
	reflex create_visitors_public_trans
		when: 
		current_date.hour <= 10
		and length(buildings where(each.state ='mobility'))>0 
		and visitors_public_trans>1 
		and every(((3600*24)/(visitors_public_trans))#s){
			create people_visitor number:rnd(1) with:[location::one_of(buildings where(each.state ='mobility')).location] {
				my_home<- one_of(buildings where(each.state ='mobility') closest_to self) ;
			}}
	
	reflex create_visitors_car 
		when:
		current_date.hour <= 10 // todo look up jesus time
		and visitors_car>1 
		and every(((3600*24)/(visitors_car))#s) 
		and (buildings sum_of(each.nb_cars)>0) {
			create people_visitor number:rnd(1) with: [location::one_of(buildings where(each.nb_cars>1)).location] {
				my_home<- one_of(buildings where(each.nb_cars>1) closest_to self);
			}}
	
	reflex create_visitor_kids_kitas 
		when:
			current_date.hour <= 10
			and length(buildings where(each.state ='mobility')) > 0 
			and visitors_public_trans > 1 
			and every((3600*24)/(1+length(list(people_resident where (each.age ="0-6")))*3)#s) 
		{
			// @JESUS : visitors kitas based amount of resident kids`? why are they created every ~30min all over the day? are they walking to kita alone?
			// "how many seconds for kids?";
			// ((3600*24)/(1+int((int(length(list(people where (each.age ="0-6")))))*3)));  <----happens every 30 min
			create people_visitor number:rnd(1) with:[location::one_of(buildings where(each.state ='mobility')).location]{
				age<-"0-6";
				my_home<- one_of(buildings where(each.nb_cars>1) closest_to self);  // why from home with cars , are they not public transport?
			}
		}
	
	
	reflex hotspot_analysis when: every(1#h) {
		if (!export_hotspots) {
			// hotspot export disabled.
			return nil;
		}
	
		list<list<float>> agents_points;
		list<point> hotspots;
		list<int> hotspot_counts;
		
		loop group over: agent_species {
			ask group {
				agents_points <- agents_points + path_points_dbscan;
				path_points_dbscan<- [];
			}
		}
		
		// perform dbscan
		list<list<int>> dbscan_results <- dbscan(agents_points,10,20); 
		
		loop cluster over:dbscan_results {
			// ignore all clusters with only 1 point
			if length(cluster) > 1 {
				container cluster_points;
				loop point_idx over: cluster {
					// collect spatial points of this cluster
					point pt <- agents_points[point_idx];  // cast to point.
					cluster_points <- cluster_points + [pt];
				}
				// get spatial center of cluster
				hotspots<- hotspots + polygon(cluster_points).location;
				hotspot_counts <- hotspot_counts + length(cluster_points);
			}
		}
		write "hotspot count: " + hotspot_counts;
		// TODO make species hotspots and add property count. or save to normal json with count prop.
		// species hotspots with time and count, then save to geojson
		save hotspots to: "results/hotspots" + current_date.hour + ".geojson" type:json crs: "EPSG:4326";
	}
	

	reflex halt when: current_date.hour = 23 and current_date.minute = 59 {	
		
		write "Stopping simulation because it time to sleep for the agents now.";	
			
		map agents_info;
		
		// check if all subspecies are listed. CANNOT loop over people.subspecies directly
		if length(agent_species) != length(people.subspecies) {
			write "not all agents are exported: " +  string(people.subspecies);
			write "list them in  the agent_species variable in the global section!";
		}
		
		loop group over: agent_species {
			ask group {
				if (length(path_points) > 1) {
					agents_info <- agents_info + map(
						name::map(
							"name"::name,
							"path":: path_points,
							"timestamps":: path_times,
							"trips":: trips						
						)
					);
				}
			}
		}
		
		map result <- map("data"::agents_info);
		
		file all <-json_file("results/result.json", result);
		save all;
		write "saved to disk";
		
		do die;
		do pause;	
	}
}


experiment "Flow Simulation" type: gui {	
	parameter "Simulation Speed" var:cycle_equals init:30.0 min:0.1 max:60.0 category:"Calibrating";
	output{
		display charts  background: rgb(55,62,70) refresh:every(10#s) camera_interaction:false{
			chart "Agents in the simulation" type: series size:{1,0.3} position: {0,0.3} background: rgb(55,62,70) axes: #white color: #white legend_font:("Calibri") label_font:("Calibri") tick_font:("Calibri") title_font:("Calibri"){
				data "People" value: nb_people color: #pink marker_size:0 thickness:1;	
			}
		}
		display map type:java2D   background: rgb(30,40,49) camera_interaction:true draw_env:false
		{
			//image site_plan transparency:0.2 refresh:false;
			species people_resident aspect:default;
			species people_visitor aspect:default;
			species amenity_person aspect:default;
			//species pedestrian_path;
			
			overlay position: { 5, 5 } size: { 240 #px, 680 #px } background:rgb(55,62,70) transparency: 1.0 {
                rgb text_color<-rgb(179,186,196);
                float y <- 12#px;
                y <- y + 14 #px;
                draw "Number of people: " + string(nb_people) at: { 25#px, y + 8#px } color:rgb(120,125,130) font: font("Calibri", 12, #plain) perspective:true;
                y <- y + 14 #px;
                draw rectangle(nb_people, 8#px) at: { 0#px, y +4#px } color:#pink;
                y <- y + 21 #px; 
                // draw to_string(time) (at: { 25#px, y + 8#px } color:rgb(120,125,130) font: font("Calibri", 12, #plain) perspective:true;
                }
		}
	}
}