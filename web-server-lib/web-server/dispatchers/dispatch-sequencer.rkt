#lang racket/base
(require web-server/private/unchecked)
(require racket/contract
         racket/list
         (unchecked-in web-server/dispatchers/dispatch))
(provide/contract #:unprotected-submodule unchecked
 [interface-version dispatcher-interface-version/c]
 [make (() () #:rest (listof dispatcher/c) . ->* . dispatcher/c)])

(define interface-version 'v1)
(define ((make . dispatchers) conn req)
  (let loop ([dispatchers dispatchers])
    (if (empty? dispatchers)
        (next-dispatcher)
        (with-handlers ([exn:dispatcher?
                         (lambda (e) (loop (rest dispatchers)))])
          ((first dispatchers) conn req)))))
