module namespace config = "http://kitwallace.me/config" ;

declare variable $config:base :=  "/db/apps/iati-api/";
declare variable $config:data :=  concat($config:base,"data/");
declare variable $config:system :=  concat($config:base,"system/");
declare variable $config:logs :=  concat($config:base,"logs/");
declare variable $config:paths := doc(concat($config:system,"paths.xml"))/paths;
declare function config:path-at($code as xs:string) as element(path) {
   $config:paths/path[@code]
};
