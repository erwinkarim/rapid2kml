
#plan change from this to kml
require 'json'
require 'gyoku'
require 'net/http'


#file_dump = File.open(file_path + ".csv", "w")
kml_header = '<kml xmlns="http://www.opengis.net/kml/2.2" >'
kml_footer = '</kml>'

#rapidkl bus routes
#routes = { :area1 => ["B103", "B112", "B114", "B115"], 
#	:area2 => [ "E11A", "E11B", "T203", "T204", "T205", "T223", "T225", "T226", "T229", "T231", "U1", "U10", "U11", "U12", "U13", "U14", "U2", "U201", "U209", "U222", "U224", "U2A", "U3", "U4", "U5", "U6", "U7", "U8"],
#	:area3 => ["BET7", "T302", "T304", "T305", "T307", "T309", "T312", "T320", "T323", "T324", "T327", "T328", "T329", "T330", "U20", "U21", "U23", "U24", "U25", "U26", "U27", "U28", "U29", "U30", "U31", "U32", "U33", "U332", "U34", "U36"],
#	:area4 => [ "BET2", "BET8", "E1", "T405", "T408", "T410", "T416", "T417", "T418", "T419", "T421", "T422", "T424", "T427", "T428", "T430", "T433", "U40", "U41", "U411", "U412", "U412A", "U415", "U42", "U429", "U43", "U432", "U44", "U45", "U46", "U47", "U48", "U49"],
#	:area5 => [ "BET3", "BET4", "T505", "T507", "T508", "T509", "T510", "T511", "T513", "T515", "T523", "T527", "T528", "T529", "T530", "T600", "U504", "U60", "U62", "U63", "U64", "U65", "U66", "U68", "U69", "U70", "U71", "U72", "U73", "U74", "U75", "U75A", "U76" ],
#	:area6 => [ "BET1", "T601", "T602", "T603", "T604", "T607", "T608", "T610", "T622", "T624", "T625", "T626", "T627", "T628", "T628B", "T629", "T629B", "T631", "T632", "T633", "T634", "T635", "U605", "U618", "U623", "U623", "U67", "U80", "U81", "U82", "U83", "U84", "U85", "U86", "U87", "U88", "U89", "U90"]
#}
routes = { :area1 => ["B103"] }

def document_builder content
	return Gyoku.xml( { :Document => content, :key_converter => :none } )
end

def folder_builder content, name
	x = String.new
	x << "<Folder>"
	x << "<name>#{name}</name>"
	x << content
	x << "</Folder>"
	return x
end

def route_builder theroute, routeName
	# data got frmo http://jp.myrapid.com.my/query/route?&route=<route id>
	#cyle to json to produce placemark points
	placemarks = String.new
	theroute["routes"].each do |routeJson|
		#node = { :placemark => { :description => "" }, :LineString => { :coordinates => ""  } }
		routeJson["route"].first["stops"].each do |busStop|
			placemark = { :Placemark => { 
				:name => busStop["name"], 
				:styleUrl => '#icon-normal', 
				:Point => { :coordinates => busStop["location"].reverse.join(',') } 
			} }
			#puts Gyoku.xml(placemark, { :key_converter => :none } )
			placemarks <<  Gyoku.xml(placemark, { :key_converter => :none } ) + "\n"
		end
	end

	#generate the line between points
	# TODO: include data from GoogleDirectionsService
	theroute["routes"].each do |routeJson|
		linemark = { :Placemark => {
			:name => "line", 
			:styleUrl => '#line-normal', 
			:LineString => { :coordinates => "" } 
		} }
		routeJson["route"].first["stops"].each do |busStop|
			linemark[:Placemark][:LineString][:coordinates] << "#{ busStop['location'].reverse.join(',') } "
			#include lines string as well
			if !busStop['line'].empty? then
				busStop['line'].each do | lineCoor |
					linemark[:Placemark][:LineString][:coordinates] << "#{ lineCoor.reverse.join(',') } "
				end	
			end
		end
		placemarks << Gyoku.xml(linemark, { :key_converter => :none }) + "\n"
	end

	return folder_builder(placemarks, routeName)

end

def fetch_from_rapidkl routeName
	return JSON.parse( Net::HTTP.get(URI( "http://jp.myrapid.com.my/query/route?&route=#{routeName}" ) ) )
end

def style_builder
	return "
		<Style id='icon-normal'>
			<IconStyle>
				<color>ffA95B3F</color>
				<scale>1.1</scale>
				<Icon>
					<href>http://www.gstatic.com/mapspro/images/stock/959-wht-circle-blank.png</href>
				</Icon>
			</IconStyle>
			<LabelStyle>
				<scale>1.1</scale>
			</LabelStyle>
			<BalloonStyle>
				<text><![CDATA[<h3>$[name]</h3>]]></text>
			</BalloonStyle>
		</Style>
		<Style id='line-normal'>
			<LineStyle>
				<color>AAA95B3F</color>
				<width>4</width>
			</LineStyle>
			<BalloonStyle>
				<text><![CDATA[<h3>$[name]</h3>]]></text>
			</BalloonStyle>
		</Style>
	"
end

#grab data from http://jp.myrapid.com.my/query/route?&route=<route name>
#open file and put into a variable
file_path = ARGV.first

#load variable as json
if !file_path.nil? then
	y = String.new
	IO.foreach(file_path){ |x| y << x }
	theroute = JSON.parse(y)
end

#now really start build the kml file
puts kml_header

content = String.new
content << style_builder
routes.each_key do |key|
	current_area = String.new
	routes[key].each do |bus_route|
		current_area << route_builder( fetch_from_rapidkl(bus_route), bus_route)
	end
	content << folder_builder( current_area, key.to_s )
end

puts folder_builder( content, "RapidKL Bus" )

puts kml_footer

