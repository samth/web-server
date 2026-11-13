#lang racket/base
(require web-server/private/unchecked)
(require racket/contract
         racket/match
         net/url
         (unchecked-in web-server/http)
         (unchecked-in web-server/private/util)
         (unchecked-in web-server/dispatchers/dispatch))
(provide/contract #:unprotected-submodule unchecked
 [interface-version dispatcher-interface-version/c]
 [make ((symbol? . -> . dispatcher/c) . -> . dispatcher/c)])

(define interface-version 'v1)
(define ((make lookup-dispatcher) conn req)
  (define host (get-host (request-uri req) (request-headers/raw req)))
  ((lookup-dispatcher host) conn req))

;; get-host : Url (listof (cons Symbol String)) -> Symbol
(define (get-host uri headers)
  (cond
    [(url-host uri) 
     => lowercase-symbol!]
    [(headers-assq* #"Host" headers)
     => (match-lambda
          [(struct header (_ v))
           (lowercase-symbol! v)])]
    [else 'none]))
