#lang racket/base
(require web-server/private/unchecked)
(require racket/contract
         (unchecked-in web-server/http/response-structs))  

(define (real-any->response x)
  #f)

(define (any->response x)
  (if (response? x)
      x
      (real-any->response x)))

(define (set-any->response! f)
  (set! real-any->response f))

(define (can-be-response? x)
  (or (response? x)
      (and (any->response x)
           #t)))

(provide/contract #:unprotected-submodule unchecked
 [any->response (-> any/c (or/c false/c response?))]
 [set-any->response! (-> (-> any/c (or/c false/c response?)) void)]
 [can-be-response? (-> any/c boolean?)])
