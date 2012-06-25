<result>
{
let $login := xmldb:login("/db/apps/iati-api","admin","perdika")
(: let $reindex := 
(xmldb:reindex("/db/apps/iati-api/system"),

xmldb:reindex("/db/apps/iati-api/codes"),
xmldb:reindex("/db/apps/iati-api/cache/fullB")
)
:)
let $reindex := 
xmldb:reindex("/db/apps/iati-api/olap")
return $reindex
}
</result>
