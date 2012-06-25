element response {
  element context-path {request:get-context-path()},
  element uri {request:get-uri()},
  element url {request:get-url()},
  element url-dir {string-join(tokenize(request:get-url(),"/")[position() < last()],"/")},
  element effective-uri {request:get-effective-uri()},
  element context-path {request:get-context-path()},
  element hostname {request:get-hostname()},
  element path-info {request:get-path-info()},
  element query-string {request:get-query-string()},
  element remote-addr {request:get-remote-addr()},
  element remote-host {request:get-remote-host()},
  element actual-host-host {request:get-header("X-Forwarded-Host")},
  element remote-port {request:get-remote-port()},
(:  element scheme {request:get-scheme()}, :)
  element server-name {request:get-server-name()},
  element server-port {request:get-server-port()},
(:  element server-path {request:get-server-path()}, :)
  element servlet-path {request:get-servlet-path()},
(:  element multipart {request:is-multipart-content()}, 
  element file-name {request:get-uploaded-file-name()},
  element file-size {request:get-uploaded-file-size()},
 :)  
  for $attribute-name in request:attribute-names()
  return 
     element attribute{
       element name {$attribute-name},
       element value {request:get-attribute($attribute-name)}
     },
  for $parameter-name in request:parameter-names()
  return 
     element parameter{
       element name {$parameter-name},
       element value {request:get-parameter($parameter-name,())}
     },
  for $cookie-name in request:get-cookie-names()
  return 
     element cookie {
       element name {$cookie-name},
       element value {request:get-cookie-value($cookie-name)}
     },
  for $header-name in request:get-header-names()
  return 
    element header {
       element name {$header-name},
       element value {request:get-header($header-name)}
     }
}
