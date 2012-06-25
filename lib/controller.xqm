module namespace controller = "http://kitwallace.me/controller";

declare function controller:context () {
   <ul>
     <li>Parameter names: {request:get-parameter-names()}</li>
     <li>URI :{request:get-uri()}</li>
     <li>exist:path : {$exist:path}</li>
     <li>exist:resource :{$exist:resource}</li>
     <li>exist:controller : {$exist:controller}</li>
     <li>exist:prefix : {$exist:prefix}</li>
     <li>exist:root : {$exist:root}</li>  
   </ul>
};

