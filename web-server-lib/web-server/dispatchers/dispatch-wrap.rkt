#lang racket/base
(require web-server/private/unchecked)

(require racket/contract
         (unchecked-in web-server/dispatchers/dispatch)
         (unchecked-in web-server/http/request-structs)
         (unchecked-in web-server/http/response-structs)
         (prefix-in lift: (unchecked-in web-server/dispatchers/dispatch-lift)))

(provide/contract #:unprotected-submodule unchecked
 [interface-version dispatcher-interface-version/c]
 [make (-> (-> request? response?)
           (-> request? request?)
           (-> response? response?)
           dispatcher/c)])

(define interface-version 'v1)

(define (make servlet req-trans res-trans)
  (lift:make (λ (req) (res-trans (servlet (req-trans req))))))
