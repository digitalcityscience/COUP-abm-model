/**
* Name: pedestriannetwork
* Based on the internal empty template. 
* Author: andre
* Tags: 
*/


model pedestriannetwork

import "global_values.gaml"

/* Insert your model definition here */
global {
	species pedestrian_path;
	
	/// Streets | Pedestrian paths
	file<geometry> pedestrian_paths <- geojson_file(inputsFolder + "/" + "streets.geojson","EPSG:4326"); //QGIS Draw network and (Processing Toolbox:split with lines)
	graph network_pedestrian_path; //Street pedestrian network
	
	init {
		create pedestrian_path from:pedestrian_paths;
		network_pedestrian_path <- as_intersection_graph(pedestrian_path, 1);	 
	}
	
}
