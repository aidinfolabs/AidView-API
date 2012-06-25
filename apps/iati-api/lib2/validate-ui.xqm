module namespace iati-pv = "http://kitwallace.me/iati-pv";
import module namespace iati-b = "http://kitwallace.me/iati-b" at "iati-b.xqm";

import module namespace iati-l = "http://kitwallace.me/iati-l" at "iati-l.xqm";
import module namespace iati-v = "http://kitwallace.me/iati-v" at "iati-v.xqm";
import module namespace iati-c = "http://kitwallace.me/iati-c" at "iati-c.xqm";
import module namespace wfn =  "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

declare function iati-pv:validate-content($query as item(), $script as xs:string ) {

let $pipeline :=doc(concat($iati-b:system,$query/pipeline,".xml"))/pipeline
let $activity-collection := concat($iati-b:data,$query/corpus,"/activities")

return 
(: download activitySet from a URL :)
  if ($query/mode="download" and exists($query/src))
       then 
          let $activitySets := doc(concat($iati-b:data,$query/corpus,"/activitySets.xml"))/activitySets
          let $download := iati-l:download-url($query/src, $activitySets, $query/corpus, $pipeline)
          return 
            response:redirect-to(xs:anyURI(concat($script,"?type=activitySet&amp;src=",encode-for-uri($query/src))))
  else

(: --------------- type = activitySet   ---------------- :)  
  if ($query/type="activitySet" and $query/mode="view" and exists($query/src) and $query/format="html")
  then
     let $activitySets := doc(concat($iati-b:data,$query/corpus,"/activitySets.xml"))/activitySets
     let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet=$query/src]
     let $selected-activities := subsequence(subsequence($activities,$query/start),1,$query/pagesize)
     return 
     <div>
        <div class="nav">
           <a href="?">Home</a> >
           <span>{$query/src/string()}</span> >
           <a href="?type=activitySet&amp;src={encode-for-uri($query/src)}&amp;mode=analysis">Analysis</a> >
           <a href="?type=activitySet&amp;src={encode-for-uri($query/src)}&amp;mode=view&amp;format=xml">XML </a>
       </div>
       <div>
         {iati-l:list-activities($selected-activities, $query/corpus)}
         {wfn:paging(concat("?type=activitySet&amp;src=",encode-for-uri($query/src)),$query/start,$query/pagesize,count($activities))}
      </div>
    </div>
   else if ($query/type="activitySet" and $query/mode="view" and  exists($query/src) and $query/format="xml")
   then 
          doc($query/src)
   else if ($query/type="activitySet" and $query/mode="analysis" and exists($query/src) and empty($query/id))
   then  let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet=$query/src]     
         return
         <div>
          <div class="nav">
              <a href="?">Home</a> >
              <a href="?type=activitySet&amp;src={encode-for-uri($query/src)}">{$query/src/string()}</a> >
              <span>Analysis</span>
          </div>
           {iati-v:activities-analysis($activities,concat("?mode=analysis&amp;type=activitySet&amp;src=",encode-for-uri($query/src),"&amp;id="))}
         </div>
         
   else if ($query/type="activitySet" and $query/mode="analysis" and  exists($query/src) and exists($query/id))
   then  let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet=$query/src]     
         return 
            <div>
             <div class="nav">
              <a href="?">Home</a> >
              <a href="?type=activitySet&amp;src={encode-for-uri($query/src)}">{$query/src/string()}</a> >
              <a href="?type=activitySet&amp;src={encode-for-uri($query/src)}&amp;mode=analysis">Analysis</a> >
              <span>Code {$query/id/string()}</span>
          </div>
            {iati-v:path-analysis($activities,$query/id)}
            </div>
   
(: ------  type = activity ---------------- :)
 
   else if ($query/type="activity" and $query/mode="view" and exists($query/id) and $query/format="html")
        then 
           let $activity := collection($activity-collection)/iati-activity[iati-identifier=$query/id]
           let $source := $activity/@iati-ad:activitySet/string()
           return
       <div>
           <div class="nav">
           <a href="?">Home</a> >
           <a href="?type=activitySet&amp;src={encode-for-uri($source)}">{$source}</a> >
           <span>{$query/id/string()}</span>
           <a href="?mode=view&amp;type=activity&amp;id={$query/id}&amp;format=xml">XML</a>

         </div>
         <div>
              { iati-v:validate-activity($activity)}
         </div>
       </div>
       
    else if ($query/type="activity" and $query/mode="view" and exists($query/id) and $query/format="xml")
    then let $doc := collection($activity-collection)/iati-activity[iati-identifier=$query/id]
         return $doc
(: ------  type = code - master ---------------- :)
   else if ($query/type="code" and $query/mode="view" and empty($query/id))
      then 
       <div>
          <div class="nav">
           <a href="?">Home</a> >
            <span>Codelist Index</span>

          </div>
         <div class="body">
         {iati-c:code-index-as-html ()}
         </div>
       </div>
   else if ($query/type="code" and $query/mode="view" and exists($query/id))
      then  
       <div>
          <div class="nav">
           <a href="?">Home</a> >
           <a href="?type=code">Codelist Index</a>
           <span>{$query/id/string()}</span>
          </div>
         <div class="body">
         {iati-c:code-list-as-html($query/id)}
         </div>
       </div>
   else if ($query/type="rule")
   then 
    <div>
          <div class="nav">
           <a href="?">Home</a> >
            <span>Rules</span>
          </div>
         <div class="body">
         {iati-v:rules-as-html()}
         </div>
       </div>
 else 
      <div>
          <div class="nav">
           <a href="?">Home</a> >
           <a href="?type=code">Codelist Index</a> |
           <a href="?type=rule">Rules</a>
          </div>
         <div  class="body">
         <h2>Download ActivitySet</h2>

               <form action="?">
               <input type="hidden" name="mode" value="download"/>
               URL <input type="text" name="src" size="100"/>
               <input type="submit" value="Download"/>
              </form>  
       <h2>Example validations</h2>
      <ul>
          <li><a href="?mode=download&amp;type=activitySet&amp;src=http://projects.dfid.gov.uk/iati/Region/380">DFID</a></li>
          <li><a href="?mode=download&amp;type=activitySet&amp;src=http://www.unops.org/iati/iati-activities/iati_activity_AL.xml">UNOPS</a></li>
          <li><a href="?mode=download&amp;type=activitySet&amp;src=http://siteresources.worldbank.org/INTSOPE/Resources/5929468-1305310586289/WB_NI.xml">World Bank</a></li>
      </ul>

         <h2>News</h2>
      <ul>
      <li> 9 Oct 2011 - initial version released based on the current schemas and the IATI Standard</li>
      <li> 15 Oct 2011 -Use of WB sector coding will now be flagged as a missing codes</li>
      <li> 3 Nov 2011- schema has been updated </li> 
      <li> 3 Nov 2011 - codelists refreshed with the IATI standard using the XML API with the exception of 
      <ul>
      <li> OrganisationIdentifier  populated from three HTML pages</li>
      <li> SectorCategory  derived from the Sector list</li>
      </ul>
      </li>
      <li> 6 Nov 2011 new development version </li>
      </ul>
      <h2>Functionality</h2>
      <ul>
      <li>This interface validates an IATI activity document such as those registered in the <a href="http://www.iatiregistry.org/">IATI Register</a>.  A number of checks are applied:
        <ul>
          <li>Validation against the <a href="http://iatistandard.org/downloads/iati-activities-schema.xsd">XML Schema</a> </li>
          <li>Validation against <a href="?mode=view&amp;type=rule">additional rules</a>. These include:
          <ul>
          <li>Conformance to rules which cannot be checked by the XML schema such as the presence of required elements</li>
          <li>Checking code values against the <a href="http://iatistandard.org/codelists">IATI code lists</a></li>
          <li>Checking value types </li>
          There is some overlap between these checks. Additional checks will be added as this validator evolves
          </ul>
          </li>
        </ul>
        </li>
        <li>Code and reference values are de-referenced using the current codelists and the name of the code (or title of activity) is shown for comparison with the element text. </li>
        <li>All activities in a document can be analysed to show the usage of codes and their distribution in the activity set.</li>
        </ul>
      <h2>Development</h2>
      <p>Developed Oct 2011 by Chris Wallace kit.wallace@gmail.com </p>
            </div>
            <div>
           <h2>Links</h2>
            <ul>
                <li>
                    <a href="http://www.iatistandard.org">IATI Standard</a>
                </li>
                <li>
                    <a href="http://www.iatiregistry.org/">IATI Registry</a>
                </li>
                <li>
                    <a href="http://www.aidinfo.org/">AidInfo</a>
                </li>
                <li>
                    <a href="http://tools.aidinfolabs.org/">AidInfoLabs</a>
                </li>
                <li>
                    <a href="http://tools.aidinfolabs.org/explorer">IATI Data Explorer</a>
                </li>
            </ul>
            </div>
      </div>

};


