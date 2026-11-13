#lang racket/base
(require web-server/private/unchecked)
(require racket/contract)
(require (unchecked-in web-server/private/connection-manager)
         (unchecked-in web-server/http))

(define dispatcher/c
  (connection? request? . -> . any))
(define dispatcher-interface-version/c
  (symbols 'v1))
(define-struct exn:dispatcher ())
(define (next-dispatcher) (raise (make-exn:dispatcher)))

(provide/contract #:unprotected-submodule unchecked
 [dispatcher/c contract?]
 [dispatcher-interface-version/c contract?]
 [next-dispatcher (-> any)]
 [struct exn:dispatcher ()])
