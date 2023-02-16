/**
* Name: buildings
* Based on the internal empty template. 
* Author: andre
* Tags: 
*/


model buildings

import "global_values.gaml"
import "statistics.gaml"
import "amenity_schedules.gaml"
import "people.gaml"


/* Insert your model definition here */

species buildings control:fsm {
	string id; // TODO add ID to geojson!!  so it can be saved to trips
	int main_function; // starting with 1: residential
	int secondary_function; // 1060: garage
	int stories; int stories_under; int area;
	int nb_residents; int nb_workers; int nb_cars; int nb_visitors;// capacities
	int nb_residents_working_in; int nb_residents_working_out;
	float hours_spent_here_on_avg;
	
	// amenity stuff
	list<amenity_schedules>my_schedules; // visitors by hour
	list<amenity_schedules>averages;  // time spent at amenities on average
	
		
	reflex list_schedules when: every(1#h){ 
		my_schedules <- amenity_schedules where(each.hour = current_date.hour);
		averages <- amenity_schedules where(each.hour = 0);
	}
	
	// DEFININITION OF DIFFERENT STATES BUILDINGS CAN HAVE
	state portal{}
	state residential {nb_residents<-int(stories*area*0.0235); nb_workers<-(0);} // assumed average (EU28) 42.56sqm per person (0.0235 persons/sqm)
	state office {nb_residents<-0; nb_workers<-int(stories*area*0.088);} // 11.25sqm per employee in offices (0.0889 persons/sqm)
	state commercial {nb_residents<-0; nb_workers<-int(stories*area*0.02395);} // assumed average 41.745sqm per employee (0.02395 persons/sqm) 
	state industrial {nb_residents<-0; nb_workers<-int(stories*area*0.00825);} // assumed average 121.21sqm per employee (0.00825 persons/sqm)
	state parking {nb_residents<-0; nb_workers<-4;} // assumed 4 workers per parking facility
	state service {nb_residents<-0; nb_workers<-int(stories*area*0.02395);} // assumed average 41.745sqm per employee (0.02395 persons/sqm)
	state leisure {nb_residents<-0; nb_workers<-int(stories*area*0.02395);} // assumed average 41.745sqm per employee (0.02395 persons/sqm)
	state school {
		enter {
			write "i am a school";
		}
			// 1 TEACHER PER 20 STUDENTS
			nb_workers<- int( 
				length((agents of_generic_species people) where (each.age ="0-6" or each.age ="7-17"))
				/ 20
			);
	}
	state mobility{}
	
	/////// (!)TODO JESUS Attention here: Adapt Leisure/Lunch buildings once input data from GB is there
	state supermarket{nb_residents<-0; nb_workers<-int(stories*area*0.02395);} // assumed average 41.745sqm per employee (0.02395 persons/sqm)
	state coffee{nb_residents<-0; nb_workers<-int(stories*area*0.02395);}  // assumed average 41.745sqm per employee (0.02395 persons/sqm) 
	state lunch{nb_residents<-0; nb_workers<-int(stories*area*0.02395);}  // assumed average 41.745sqm per employee (0.02395 persons/sqm) 
	state kantine{nb_residents<-0; nb_workers<-int(stories*area*0.02395);}  // assumed average 41.745sqm per employee (0.02395 persons/sqm) 
	
	
	// AMENITY STATES
	state university {nb_visitors<- int((one_of (my_schedules)).university); hours_spent_here_on_avg<-(one_of (averages)).university; }
	state highschool {nb_visitors<- int((one_of (my_schedules)).highschool); hours_spent_here_on_avg<-float((one_of (averages)).highschool); }
	state creative_space {nb_visitors<- int((one_of (my_schedules)).creative_space); hours_spent_here_on_avg<-float((one_of (averages)).creative_space); }
	state event_space {nb_visitors<- int((one_of (my_schedules)).event_space); hours_spent_here_on_avg<-float((one_of (averages)).event_space); }
	state museum {nb_visitors<- int((one_of (my_schedules)).museum); hours_spent_here_on_avg<-float((one_of (averages)).museum); }
	state library {nb_visitors<- int((one_of (my_schedules)).library); hours_spent_here_on_avg<-float((one_of (averages)).library); }
	state religious {nb_visitors<- int((one_of (my_schedules)).religious); hours_spent_here_on_avg<-float((one_of (averages)).religious); }
	state health_center {nb_visitors<- int((one_of (my_schedules)).health_center); hours_spent_here_on_avg<-float((one_of (averages)).health_center); }
	state community_center {nb_visitors<- int((one_of (my_schedules)).community_center); hours_spent_here_on_avg<-float((one_of (averages)).community_center); }
	state kita {nb_visitors<- int((one_of (my_schedules)).kita); hours_spent_here_on_avg<-float((one_of (averages)).kita); }
	state sports_facility {nb_visitors<- int((one_of (my_schedules)).sports_facility); hours_spent_here_on_avg<-float((one_of (averages)).sports_facility); }
	state toilet {nb_visitors<- int((one_of (my_schedules)).toilet); hours_spent_here_on_avg<-float((one_of (averages)).toilet); }
	state praxis_specialist {nb_visitors<- int((one_of (my_schedules)).praxis_specialist); hours_spent_here_on_avg<-float((one_of (averages)).praxis_specialist); }
	state praxis_general {nb_visitors<- int((one_of (my_schedules)).praxis_general); hours_spent_here_on_avg<-float((one_of (averages)).praxis_general); }
	state park{ nb_visitors<- int((one_of (my_schedules)).community_center); hours_spent_here_on_avg<-float((one_of (averages)).community_center); }

	reflex clean when:cycle=100 { if state="non_classified" {
		write "COULD NOT CLASSIFY BUILDING WITH GFK "+ main_function;
		do die;
		} 
	}
	
	
	/** POPULATION COUNT UPDATES */
	action calculate_parking_spots{ //for buildings with underground car park: assumed 4 cars per 100sqm (0.04 cars/sqm)
		if secondary_function = 1060 { 
			nb_cars <-int((stories_under*area)*0.04);
		}
		if (
			// ALKIS codes for garage, vechile depot, ...
			main_function>=2460 
			and main_function<2500
		) {
			nb_cars <-int((stories*area)*0.04);
		}
		else {
			nb_cars<-0;
		}
	}
	reflex calculate_residents_workplace when: state='residential' and nb_residents>1 and every(1#mn) {
		nb_residents_working_in <- int(nb_residents * ((statistics where(each.Work_School ='inside') sum_of (each.Percent_Work))/100));
		nb_residents_working_out <- int(nb_residents * ((statistics where(each.Work_School ='outside') sum_of (each.Percent_Work))/100));
	}
	
	/** CONTINUESLY CREATE POPULATION */
	
	
	reflex create_residents_working_in when: state='residential' and nb_residents_working_in>1 and every(((3600*6)/(nb_residents_working_in/rnd(1,5)))#s) and current_date.hour between(4,10){ //all buildings create residents = nb_residents. nb_residents are distributed equally during leave_home hours (4am to 10am)
		create people_resident number:rnd(1) with:[location::location]{my_home<-myself; }
	}
	reflex create_residents_working_out when: state='residential' and nb_residents_working_out>1 and every(((3600*6)/(nb_residents_working_out/rnd(1,5)))#s) and current_date.hour between(4,10){ //all buildings create residents = nb_residents. nb_residents are distributed equally during leave_home hours (4am to 10am)
		create people_resident number:rnd(1) with:[location::location]{my_home<-myself; my_workplace<- buildings where(each.state='mobility') closest_to self;}
	}

	
	/** @ JESUS : should they be created at portals? */
	
	
	
	reflex create_amenity_persons when: 
		current_date.hour >= 9 and current_date.hour < 22
		and nb_visitors>1 
		and every((1/nb_visitors)#h) {
			 //all buildings create residents = nb_residents. nb_residents are distributed equally during leave_home hours (4am to 10am)
			
			list<buildings> potential_homes <- buildings where (each.state = "mobility");
			int max_distance <- 2000;
			
			// A certain percentage of people does not arrive with public transport and is assumed to live in the sim. area.
			if (rnd(1,100) > amenity_visitors_arriving_with_pt) {
				potential_homes <- buildings where (each.state = "residential");
				max_distance <- 1500;
			} 
			buildings his_home <- find_building_in_walking_distance(self, potential_homes,  max_distance, "amenity") ; 
			
			if (his_home != nil) {
				create amenity_person number:1 with:[location::point(his_home.location)]{my_home <- his_home; my_amenity<-myself; time_i_will_spend_at_amenity<-myself.hours_spent_here_on_avg;}
				// write "created amenity person for " + state + nb_visitors;
			}	
		}

	buildings find_building_in_walking_distance(buildings start, list potential_destinations, int max_distance, string agentsName, int tries<-1) {
		
		// write "searching place for agent: " + agentsName + " " + length(potential_destinations);
		if length(potential_destinations) = 0 {
			//write "no pot destinations for agent " + agentsName;
			return nil;
		}
		
		
		if tries > 200  {
			write "no matching building found";
			return nil;
		}
		
		buildings chosen_building<- one_of(potential_destinations);
		
		path test_path <- path_between(network_pedestrian_path, start.location, chosen_building.location);		
		if (test_path != nil) {
			// check distance along path
			if (test_path.shape.perimeter < max_distance and test_path.shape.perimeter > 10) {
				// yeah! found a building in walking distance.
				return chosen_building;
		}
		
	
		// try finding again	
		tries <- tries + 1;
		potential_destinations <- potential_destinations - chosen_building;
		
		return find_building_in_walking_distance(start, potential_destinations, max_distance, agentsName, tries);
		}
		
	}
	

	state non_classified initial:true{
	
		/*** 
		 * THIS IS NOT A GOOD MAPPING: IT IS HIGHLY ERROR PRONE ON POSITIONING OF IF/ELSE STATEMENTS AS MAPPING RANGES OVERLAPP 
		 * AND IT IS HARD TO READ FOR HUMANS WHATS STATE A BUILDING WOULD BE SORTED TO
		 * TRY TO GO FROM SPECIFIC TO UNSPECIFIC
		 * */
		
		do calculate_parking_spots;
		
		transition to: supermarket when:(secondary_function=1230);
		transition to: portal when:(main_function=0);		
		
		
		// amenity transitions
		transition to: university when:(main_function=3023);
		transition to: highschool when:(main_function=3025);
		transition to: creative_space when:(main_function=3030);
		transition to: event_space when:(main_function=3033);
		transition to: museum when:(main_function=3034);
		transition to: library when:(main_function=3037);
		transition to: religious when:(main_function=3040);
		transition to: health_center when:(main_function=3053);
		transition to: community_center when:(main_function=3062);
		transition to: sports_facility when:(main_function=3210);
		transition to: toilet when:(main_function=2612);
		transition to: kantine when:(main_function=2083);
		

		/////// (!)TODO JESUS Attention here: Adapt Leisure/Lunch buildings once input data from GB 
		transition to: park when:(
			main_function>=1
			and main_function<=3
		);
			
		
		transition to: residential when:(
			main_function>=1000 
			and main_function<2000
		);
		

		transition to: office when:(
			main_function>=2020 
			and main_function<=2040
		);
				
		transition to: lunch when:(
			(
				main_function>=2080 
				and main_function<=2081
			)
			or main_function=2086
		);
		
		transition to: coffee when:(
			main_function>2083 
			and main_function<=2085
		);
			
		
		transition to: leisure when:(
			(
				main_function>=2060 
				and main_function<2100
			)
			or(
				main_function>=3200
			)
		);
		
		transition to: commercial when:(
			(
				main_function>=2000 
				and main_function<2020
			)
			or(
				main_function>=2050 
				and main_function<2056
			)	
		);
		
		
		transition to: industrial when:(
			(
				main_function>=2100 
				and main_function<2460
			)
			or(
				main_function>=2500 
				and main_function<3000
			)
		);
		transition to: parking when:(
			main_function>=2460 
			and main_function<2500
		);
		
		transition to: service when:(
			(
			main_function>=3000 
			and main_function<3021
			)
			or(
				main_function>3030
				and main_function<3091
			)
			or (
				(main_function>3097)
			)
		);
		
		transition to: school when:(
			main_function>=3021 
			and main_function<=3026
		);
		
		transition to: praxis_general when:(
			main_function>=3050 
			and main_function<=3056
		);
		
		transition to: mobility when:(
			main_function>=3091
			and main_function<=3097
		);
	}
}