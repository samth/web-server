#lang racket/base
(require web-server/private/unchecked)

(require racket/contract
         (unchecked-in web-server/dispatchers/dispatch)
         (unchecked-in web-server/http)
         (only-in (unchecked-in web-server/private/util)
                  bytes-ci=?))

(provide/contract #:unprotected-submodule unchecked
 [interface-version dispatcher-interface-version/c]
 [make (-> (or/c symbol? (cons/c symbol? (listof symbol?)))
           dispatcher/c
           dispatcher/c)])

(define interface-version 'v1)

; symbol? -> bytes?
;
; uppercase the (name of the) symbol to optimized for the
; normal case, where HTTP methods are given in uppercase
; ("GET", "HEAD", etc.)
(define (symbol->bytes symb)
  (string->bytes/utf-8 (string-upcase (symbol->string symb))))

; request? (listof bytes?) -> boolean?
(define (can-request-pass-through? req methods)
  (member (request-method req)
          methods
          bytes-ci=?))

(define (make methods inner)
  (define methods/bytes/list
    (if (symbol? methods)
        (list (symbol->bytes methods))
        (map symbol->bytes methods)))
  (lambda (conn req)
    (cond [(can-request-pass-through? req methods/bytes/list)
           (inner conn req)]
          [else (next-dispatcher)])))
