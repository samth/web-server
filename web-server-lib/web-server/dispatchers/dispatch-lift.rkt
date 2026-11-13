#lang racket/base
(require web-server/private/unchecked)
(require racket/contract)
(require (unchecked-in web-server/dispatchers/dispatch)
         (unchecked-in web-server/http)
         (unchecked-in web-server/http/response))
(provide/contract #:unprotected-submodule unchecked
 [interface-version dispatcher-interface-version/c]
 [make ((request? . -> . response?) . -> . dispatcher/c)])

(define interface-version 'v1)
(define ((make procedure) conn req)
  (output-response/method
   conn
   (procedure req)
   (request-method req)))
