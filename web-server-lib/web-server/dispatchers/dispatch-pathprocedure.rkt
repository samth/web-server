#lang racket/base
(require web-server/private/unchecked)
(require racket/contract
         net/url)
(require (unchecked-in web-server/dispatchers/dispatch)
         (unchecked-in web-server/private/util)
         (unchecked-in web-server/http)
         (unchecked-in web-server/http/response))
(provide/contract #:unprotected-submodule unchecked
 [interface-version dispatcher-interface-version/c]
 [make (string? (request? . -> . response?) . -> . dispatcher/c)])

(define interface-version 'v1)
(define ((make the-path procedure) conn req)
  (define path (url-path->string (url-path (request-uri req))))
  (if (string=? the-path path)
      (output-response/method
       conn
       (procedure req)
       (request-method req))
      (next-dispatcher)))
