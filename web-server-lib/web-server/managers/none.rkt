#lang racket/base
(require web-server/private/unchecked)
(require racket/contract)
(require (unchecked-in web-server/managers/manager))
(require (unchecked-in web-server/servlet/servlet-structs)
         (unchecked-in web-server/http))
(provide/contract #:unprotected-submodule unchecked
 [create-none-manager
  (-> 
   (or/c false/c
         (request? . -> . can-be-response?))
   manager?)])

(define-struct (none-manager manager) (instance-expiration-handler))
(define (create-none-manager
         instance-expiration-handler)
  
  (define (create-instance expire-fn)
    0)
  (define (adjust-timeout! instance-id secs)
    (void))
  
  (define (instance-lookup instance-id)
    (raise (make-exn:fail:servlet-manager:no-instance
            (format "No instance for id: ~a" instance-id)
            (current-continuation-marks)
            instance-expiration-handler)))
  
  (define (clear-continuations! instance-id)
    (instance-lookup instance-id))
  
  (define (continuation-store! instance-id k expiration-handler)
    (instance-lookup instance-id))
  (define (continuation-lookup instance-id a-k-id a-salt)
    (instance-lookup instance-id))
  
  (make-none-manager create-instance 
                     adjust-timeout!
                     clear-continuations!
                     continuation-store!
                     continuation-lookup
                     continuation-lookup
                     ; Specific
                     instance-expiration-handler))
