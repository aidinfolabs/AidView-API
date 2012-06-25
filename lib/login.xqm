module namespace login = "http://kitwallace.me/login";
import module namespace ui = "http://kitwallace.me/ui" at "/db/lib/ui.xqm";

declare variable $login:register-form :=
    <entity name="member">
        <attribute name="membername"/>
        <attribute name="email"/>
        <attribute name="password" form-type="password"/>
        <attribute name="password2" form-type="password"/>
        <attribute name="secret" form-type="password"/>
    </entity>;
    
declare variable $login:login-form :=
    <entity name="member">
        <attribute name="email"/>
        <attribute name="password" form-type="password"/>
    </entity>;

declare function login:login-form() {
 <div>
   <form action="?" method="post">
     <input type="hidden" name="mode" value="login"/>
     {ui:entity-to-form($login:login-form)}
     <input type="submit" value="Login"/>
   </form>
 </div>
};

declare function login:login($members) {
  let $member := ui:get-entity($login:login-form)
  let $emember := $members/member[email=$member/email]
  return
    if (exists ($member) and exists($emember) and  util:hash($member/password,"MD5") = $emember/password)
    then 
       let $session := session:set-attribute("membername",$emember/membername/string()) 
       return request:redirect-to(xs:anyURI(request:get-url()))
    else 
       login:login-form()
};

declare function login:logout() {
  let $invalidate := session:invalidate()
  return
     request:redirect-to(xs:anyURI(request:get-url()))
};

declare function login:create-member($members, $membername, $email, $password) {
  let $member := 
<member>
   <membername>{$membername}</membername>
   <email>{$email}</email>
   <password>{util:hash($password,"MD5")}</password>
   <date-joined>{current-date()}</date-joined>
</member>
  let $update := if (exists($members/member[membername=$membername]))
                 then <error>membername already exists</error>
                 else update insert $member into $members 
   return $update
};

declare function login:add-member-to-query($entity) {
  element {name($entity)} {
    $entity/*,
    let $membername := session:get-attribute("membername")
    return 
       if (empty($membername)) then () else  element membername {$membername}
  }
};

declare function login:register($query) {
 <div>
    
     <form action="?" method="post">
        <input type="hidden" name="mode" value="add-member"/>
        {ui:entity-to-form($login:register-form)}
        <input type="submit" value="register"/>
     </form>
 </div>
};

declare function login:add-member ($query,$members) {
let $member := ui:get-entity($login:register-form)
let $emember := $members/member[membername = $member/membername]
return
if (empty($emember) and $member/password ne "" and $member/password = $member/password2  and contains($member/email,"@") and $member/secret = "pigstyhill")
then  
   let $login := login:create-member($members,$member/membername/string(),$member/email/string(),$member/password/string())
   return true()
else 
  false()
};
