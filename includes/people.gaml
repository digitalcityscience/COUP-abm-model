/**
* Name: people
* Based on the internal skeleton template. 
* Author: andre
* Tags: 
*/

model people

import "pedestrian_network.gaml"
import "buildings.gaml"


	/** Insert the global definitions, variables and actions here */
	
	species people skills: [moving] control:fsm {
	
		// values for animation only
		aspect default {draw circle(3) at:{location.x+3*offsetx,location.y+3*offsety} color:color;}
		int offsetx <- rnd(2); int offsety <- rnd(2); rgb color;
	
		// my properties
		float speed <-rnd(2.5,6.0);
		string age;
		int my_leisure_prob<- rnd(1,100);
		int my_lunch_outside_prob<- rnd(1,100);
		int my_coffee_after_lunch_prob<- rnd(1,100);
		
	
		// my places
		buildings my_workplace; 
		buildings my_home;
		buildings my_leisure;
		buildings my_lunch;
		buildings my_coffee;
		
		// routine stati
		bool had_lunch <- false;
		
				
		// for the save routine
		list<list<float>> path_points;
		list<list<float>> path_points_dbscan;
		point prev_path_point;
		list<float> path_times;
		
		geometry prev_edge <- nil;
		list<map> trips;
		
		action init_agent virtual:true; 
		
		/** STATES **/	
		state init_state initial:true {
			// virtual action select agent's places and set individual variables
			do init_agent;
			
			// rename into start day
			transition to: start_agent_day;
		}
		
	   	
		/** GO TO WORK */
		state start_agent_day {
			enter { 
				float trip_start_time <- time;
			}
			
			if my_workplace = nil {
				do die;
			}
		
			do walk(my_workplace.location);
			transition to: at_work  when: location = my_workplace.location;	
			
			exit {			
				do save_trip(
					my_home.location,
					my_workplace.location,
					my_home.id,
					my_workplace.id,
					trip_start_time,
					time,
					"to_work"
				);
			} 
		}
	
		/** WORKDAY */
		state at_work {
			enter {
				date time_for_lunch <- date([current_date.year, current_date.month, current_date.day ,rnd(11,14),rnd(0,59),0]);
				date time_work_end <- date([current_date.year, current_date.month, current_date.day ,rnd(16,20),rnd(0,59),0]);
			}
			
			// go out for lunch
			bool lunch_out <- my_lunch != nil and lunch_outside_prob >= my_lunch_outside_prob;
			transition to: going_to_lunch when: !had_lunch and lunch_out and time_for_lunch < current_date;
			
			// go to leisure
			bool leisure <- my_leisure != nil and leisure_prob>=my_leisure_prob;
			transition to: going_to_leisure when: leisure and time_work_end < current_date;
			
			// go home
			transition to: going_home when:  !leisure and time_work_end < current_date;
		}
		
	
		/** LUNCH BREAK */
		state going_to_lunch {
			enter {
				float trip_start_time <- time;
			}
			
			do walk(my_lunch.location);
			transition to: at_lunch when: location = my_lunch.location;		
			
			exit {
				do save_trip(
					my_workplace.location,
					my_lunch.location,
					my_workplace.id,
					my_lunch.id,
					trip_start_time,
					time,
					"to_lunch"		
				);
			} 
		}
	
		state at_lunch {
			enter {
			 	date time_to_go_back <- current_date + 1#h;
			}
			
			bool coffee_out <- my_coffee != nil and coffee_after_lunch_prob >= my_coffee_after_lunch_prob;
					
			transition to: go_to_coffee when: coffee_out and (time_to_go_back minus_minutes 15) < current_date;
			transition to: go_back_to_work when: time_to_go_back < current_date;
		}
		
		/** COFFEE AFTER WORK?? */
		state go_to_coffee {
			enter {
			 	float trip_start_time <- time;
			}
			
			do walk(my_coffee.location);
			transition to: at_coffee_place when:  location = my_coffee.location;	
			
			exit {
				do save_trip(
					my_lunch.location,
					my_coffee.location,
					my_lunch.id,
					my_workplace.id,
					trip_start_time,
					time,
					"coffee_after_lunch"
				);
			} 
		}
		
		state at_coffee_place {
			enter {
				date time_to_leave <- current_date + 20#m;
			}
				transition to: go_back_to_work when: time_to_leave < current_date;
		}
		
		/** BACK TO WORK AFTER LUNCH/COFFEE */
		state go_back_to_work {
			enter {
				had_lunch <- true;
				point trip_start_location <- location;
				float trip_start_time <-  time;
			}
			
			do walk(my_workplace.location);
			transition to: at_work when: location = my_workplace.location;		
			
			exit {
				do save_trip(
					trip_start_location,
					my_workplace.location,
					my_lunch.id,
					my_workplace.id,
					trip_start_time,
					time,
					"return_from_lunch_break"
				);
			} 
		}
	
	
		/** AFTER WORK */		
		state going_to_leisure {
			enter {
				float trip_start_time <- time;
			}
						
			do walk(my_leisure.location);
			transition to: at_leisure when: location = my_leisure.location;		
			
			exit {
				do save_trip(
					my_workplace.location,
					my_leisure.location,
					my_workplace.id,
					my_leisure.id,
					trip_start_time,
					time,
					"to_leisure"
				);
			} 
		}
		
		state at_leisure {
			enter {
				date time_to_leave <- date([current_date.year,current_date.month,current_date.day,rnd(current_date.hour,22),rnd(0,59),0]);
			}
					transition to: going_home when: time_to_leave < current_date;
		}
		
	
		state going_home {
			enter {
				float trip_start_time <- time;
			}
			
			do walk(my_home.location);
			
		
			transition to: back_home when: location = my_home.location;
			exit { 
				do save_trip(
					my_workplace.location,
					my_home.location,
					my_workplace.id,
					my_home.id,
					trip_start_time,
					time,
					"to_home"
				);		
			}
		}
		
		state back_home {
			// just chill.
		}


	/** ACTIONS **/
	action walk(point target) {
		path path_followed<- goto(
			target: target, 
			on: network_pedestrian_path, 
			speed:speed#km/#h,
			return_path: true
			); 

		do save_movement(path_followed);
	}
	
	action select_age{		
		list<statistics>my_age_options<- statistics where(each.Age != nil);
		list<statistics>my_age_choices;
		loop obs over: my_age_options{
			my_age_choices<-my_age_choices+list_with(obs.Percent_Age,obs);
		}
		age<- one_of(my_age_choices).Age;
	}
	
	action select_workplace {
		// write "selecting workplace for " + name;
		
		list<buildings> pot_workplaces;
		
		// choose schools or offices depending on age
		if (age != "0-6" and age != "7-17") {
			pot_workplaces <- buildings where (each.nb_workers > 1);
		} else {
			pot_workplaces <- buildings where (each.state = "school");
		}
		
			
		if length(pot_workplaces) = 0 {
			return nil;
		}
				
		ask my_home {
			myself.my_workplace <- find_building_in_walking_distance(self, pot_workplaces, 1000, myself.name);
		}	
	}
	
	
	action select_leisure_place {
		ask my_workplace {
			myself.my_leisure <- find_building_in_walking_distance(
				self, 
				buildings where ((each.state="commercial") or (each.state="service") or (each.state="leisure")), 
				1000,
				myself.name
			);
		}
	}
	
	action select_lunch_place {
		if my_lunch=nil{ ask my_workplace { myself.my_lunch <- find_building_in_walking_distance(self, buildings where (each.state="kantine"), 500, myself.name);}}
		if my_lunch=nil{ ask my_workplace { myself.my_lunch <- find_building_in_walking_distance(self, buildings where (each.state="lunch"), 750, myself.name);}}
		if my_lunch=nil{ ask my_workplace { myself.my_lunch <- find_building_in_walking_distance(self, buildings where (each.state="supermarket"), 750, myself.name);}}
		if my_lunch=nil{ ask my_workplace { myself.my_lunch <- find_building_in_walking_distance(self, buildings where (each.state="park"), 750, myself.name);}}
		if my_lunch=nil{ ask my_workplace { myself.my_lunch <- find_building_in_walking_distance(self, buildings where (each.state="coffee"), 500, myself.name);}}
	}
	
	action select_coffee_place {
		// find a coffee place at distance of 500m around lunch location
		if my_lunch != nil {				
			ask my_lunch {
				myself.my_coffee <- find_building_in_walking_distance(self, buildings where (each.state = "coffee"), 500, myself.name);
			}
		}
	}
	
	

	/** EXPORT RESULT ACTIONS */
		
	// saves a single movement to agent's path_points and path_times
	action save_movement(path path_taken) {		
		// an agent's first steps
		if prev_edge = nil {
			do save_position_and_time(path_taken.source, (int(time-step)));  // agent started here.
			do save_position_and_time(path_taken.target); // arrived here.
			
			return nil;  // done; early return
		}
			
		
		// still on same edge. save current location on edge, if agent moved more than 50m
		if (prev_edge = current_edge) {	
			if (path_taken.shape.perimeter > 25) {
				do save_position_and_time(path_taken.target);
				// do save_position_for_hotspot_analysis(path_taken.target);
			}
			
			return nil; // done; early return
		}
		 
		//Agent is on a new edge ,save current position.
		do save_position_and_time(path_taken.target);	
		
		return nil;	
				
		/* if you have a path network with very short paths, this might be raised often.
		 *	maybe you'd want to improve the logging logic then.
		do warn_if_inaccurate_path_record(path_taken);
		*/
	}
	
	action save_position_and_time(
		point position_to_add, 
		int at_time<-time
	) {
		
		// dont save the same position multiple times.
		if prev_path_point != nil {
			if prev_path_point = position_to_add {
				return nil;
			}
		}
		
		point pos <-  point(CRS_transform(position_to_add));
		path_points <- path_points + [[pos.x, pos.y]];  
		path_times <- path_times + at_time;
		prev_edge <- current_edge;
		prev_path_point <- position_to_add;
	}
	
	point find_passed_node {
		if (current_edge = nil) or prev_edge = nil {
			return nil;
		}
		list<point> closest_points <- closest_points_with(current_edge, prev_edge);
		if distance_to(closest_points[0], closest_points[1]) = 0.0 {
			return closest_points[0];
		}
	}
	
	action save_position_for_hotspot_analysis(point agent_location) {
		path_points_dbscan <- path_points_dbscan + [[agent_location.x, agent_location.y]];
	}
	
	
	// saves a trip to agent's "trips" list
	action save_trip(
		point origin_pt,
		point destination_pt,
		string origin_name,
		string destination_name,
		float start_time, 
		float end_time,
		string trip_purpose
	) {
		int trip_length <- int(path_between(network_pedestrian_path, origin_pt.location, destination_pt.location).shape.perimeter);
		
		if trip_length = nil {
			return nil;
		}
		
		
		if end_time = start_time {
			// very short trips and in the same cycle
			end_time <- start_time +  (1/ (speed / trip_length));
		} 
		
		float trip_speed <- (end_time - start_time) / trip_length;

		map trip <- map(
			"start_time"::int(start_time),
			"end_time"::int(end_time),
			"origin_name":: origin_name,
			"destination_name":: destination_name,
			"trip_purpose"::trip_purpose,
			"trip_length"::trip_length,
			"trip_speed"::trip_speed
		);	
		
		trips <- trips + [trip];
	}
	
	action warn_if_inaccurate_path_record(path path_taken) {
		point node <- find_passed_node();
		
		if node = nil {
			// happens if the agent passed more than 1 node/street segment on their path
			if path_taken.shape != nil and path_taken.shape.perimeter > 100 {
				// prev_node and current_node do not intersect. 
				// Linear Interpolation between path points will not follow the nodes of the network.
				// TODO reconstruct path with more detail in this case. with path_taken.segments
				write "WARNING: agent used several graph edges on his path. inaccurate export." ;
				write "distance walked in m:";
				write path_taken.shape.perimeter;	
			}
		}
	
		/**
		 * HOW TO MAKE LOGGING MORE ACCURATE?
		 * 
		 *  one option would be to save the node position, instead of the actual end position of this movement.
	      otherwise the edge to this node might be skipped in reconstruction/interpolation of path and the agent goes "off the street".
	 	 * do save_position_and_time(node, time-15#s);		
	
		 * For the grasbrook this led to painfully accurate results, that just looked bad in the browser rendering, 
		 * bc each agent would be visualized walking on the exact same cm of the road as all others. 
		 */
	}
	

	/** REFLEXES **/
	reflex clean when:current_date.hour=0 and current_date.minute=0 {do die;} // @JESUS: why??
}

	/** CHILD IMPLEMENTATIONS */	
	species people_visitor control:fsm parent:people {
		
		action init_agent {	
			//rgb color<-#yellow;
			bool is_visitor<- true;
		
			do select_age;
			do select_workplace;
			
			
			if my_workplace != nil {
				do select_leisure_place;
				do select_lunch_place;
				do select_coffee_place;	
			}
			else {
				// killing bc no work for " + name + " " + age;
				do die;
			}
						
		}
	}

	species people_resident control:fsm parent:people {
		
		action init_agent {	
			//rgb color<-#pink;
			bool is_visitor<- false;
		
			do select_age;
			do select_workplace;
			
			if my_workplace != nil {
				do select_leisure_place;
				do select_lunch_place;
				do select_coffee_place;	
			} else {
				//write "killing bc no work for " + name + " " + age;
				do die;
			}
			
		}
	}

		
	species amenity_person skills: [moving] control:fsm parent: people{
		buildings my_amenity;
		float time_i_will_spend_at_amenity;
	
		action init_agent {
			// nothing to do?		
		}
			
		state start_agent_day {
			enter {
				float trip_start_time <- time;
			}
					
			do walk(my_amenity.location);
			transition to: at_amenity when: location = my_amenity.location;		
			
			exit {
				do save_trip(
					my_home.location,
					my_amenity.location,
					my_home.id,
					my_amenity.id,
					trip_start_time,
					time,
					"to_amenity"
				);
			} 
		}
	
		state at_amenity {
			enter {
				date time_to_leave <- current_date + time_i_will_spend_at_amenity#h;
			}
				transition to: going_home when: time_to_leave < current_date;
		}
	
	
		state going_home {
			enter {
				float trip_start_time <- time;
			}
			do walk(my_home.location);
		
			transition to: back_home when: location = my_home.location;
			exit { 
				do save_trip(
					my_amenity.location,
					my_home.location,
					my_amenity.id,
					my_home.id,
					trip_start_time,
					time,
					"amenity_to_home"
				);
			}
		}
	}