module namespace gmap="http://kitwallace.me/gmap";
declare namespace kml = "http://earth.google.com/kml/2.0";
declare variable $gmap:googleKey :=  "ABQIAAAAVehr0_0wqgw_UOdLv0TYtxSGVrvsBPWDlNZ2fWdNTHNT32FpbBR1ygnaHxJdv-8mkOaL2BJb4V_yOQ";
declare variable $gmap:googleUrl := "http://maps.google.com/maps/geo?q=";
import module namespace geo="http://kitwallace.me/geo" at "/db/lib/geo.xqm";

declare function gmap:LatLong-as-kml($p as element(geo:LatLong)) as xs:string {
     concat($p/@longitude,',',$p/@latitude,',0')
};

declare function gmap:path-to-linestring($points as element(point)* )  as element(LineString) {
(: points have latitudes and longitudes
:)
   <LineString>
   <coordinates>
   
  {
     for $point in $points
     return
          concat($point/@longitude,',',$point/@latitude,',0  ')
   }
  </coordinates>
  </LineString>
};

declare function gmap:pause($n) {
(: a pretty bad way to slow the script down to avoid Google throttling me :)
  for $i in (1 to $n)
  let $x := doc("http://en.wikipedia.org/wiki/UWE")
  return ()
};

declare function gmap:geocode($location) {
let $location := normalize-space($location)
let $location := encode-for-uri($location)
let $url := concat($gmap:googleUrl,$location,"&amp;output=xml&amp;key=",$gmap:googleKey)
let $response := doc($url)
let $place := $response//kml:Placemark[1]
let $point := $place/kml:Point/kml:coordinates
let $coords := tokenize($point,",")
return 
  if (exists($coords))
  then geo:LatLong(xs:double($coords[2]),xs:double($coords[1]))
  else ()
};

declare function gmap:geocode($location,$n) {
let $x := gmap:pause($n)
let $location := normalize-space($location)
let $location := encode-for-uri($location)
let $url := concat($gmap:googleUrl,$location,"&amp;output=xml&amp;key=",$gmap:googleKey)
let $response := doc($url)
let $place := $response//kml:Placemark[1]
let $point := $place/kml:Point/kml:coordinates
let $coords := tokenize($point,",")
return 
  if (exists($coords))
  then geo:LatLong(xs:double($coords[2]),xs:double($coords[1]))
  else ()
};

declare function gmap:multi-geocode($location) {
let $location := normalize-space($location)
let $location := escape-uri($location,false())
let $x := gmap:pause(1)
let $url := concat($gmap:googleUrl,$location,"&amp;output=xml&amp;key=",$gmap:googleKey)
let $response := doc($url)
for $place in $response//kml:Placemark
  let $point := $place/kml:Point/kml:coordinates
  let $coords := tokenize($point,",")
  return 
      geo:LatLong($coords[2],$coords[1])
};
