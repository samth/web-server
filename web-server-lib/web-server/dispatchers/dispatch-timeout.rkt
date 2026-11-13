#lang racket/base
(require web-server/private/unchecked)
(require racket/contract)
(require (unchecked-in web-server/dispatchers/dispatch)
         (unchecked-in web-server/private/connection-manager))
(provide/contract #:unprotected-submodule unchecked
 [interface-version dispatcher-interface-version/c]
 [make (integer? . -> . dispatcher/c)])

(define interface-version 'v1)
(define ((make new-timeout) conn req)
  (adjust-connection-timeout! conn new-timeout)
  (next-dispatcher))
