declare option exist:serialize "method=text media-type=text/text";

let $login := xmldb:login("/db","admin","perdika")
let $path := "file:///usr/local/exist/webapp/WEB-INF/data/oldfs/fs/db/apps/logger/xquery/browse.xq"
let $contents := util:binary-to-string(file:read-binary($path))
return 
  $contents
  
