#lang racket/base
;; `unchecked-in` lets web-server's own modules import the uncontracted versions of
;; bindings that another web-server module provides with contracts.
;;
;; A module opts in by adding `#:unprotected-submodule unchecked` to its (single)
;; `provide/contract` or `contract-out` form. Then, inside web-server,
;;
;;   (require (unchecked-in web-server/http/request-structs))
;;
;; imports everything the module provides, taking the contracted bindings from its
;; `unchecked` submodule instead. Contracts stay on the public API: other packages
;; keep importing the module itself. Use it only in modules that do not re-export the
;; imported bindings, or the re-exports would lose their contracts.
(require (for-syntax racket/base racket/require-transform))
(provide unchecked-in)

(define-syntax unchecked-in
  (make-require-transformer
   (lambda (stx)
     (syntax-case stx ()
       [(_ mp ...)
        ;; Expand each part separately instead of using `combine-in`, which
        ;; rejects some modules that export lifted identifiers.
        (let loop ([specs
                    (apply append
                           (for/list ([mp (in-list (syntax->list #'(mp ...)))])
                             (define sub (datum->syntax mp `(submod ,mp unchecked) mp))
                             (define (phase-0-names mod)
                               (for*/list ([phase+names (in-list (syntax-local-module-exports mod))]
                                           #:when (eqv? (car phase+names) 0)
                                           [name (in-list (cdr phase+names))])
                                 name))
                             ;; The submodule can also export names the module itself
                             ;; does not, so exclude only names that both provide.
                             (define main-names (phase-0-names mp))
                             (define names
                               (for/list ([name (in-list (phase-0-names sub))]
                                          #:when (memq name main-names))
                                 (datum->syntax mp name mp)))
                             (list #`(except-in #,mp #,@names) sub)))]
                   [imports '()]
                   [sources '()])
          (if (null? specs)
              (values imports sources)
              (let-values ([(is ss) (expand-import (car specs))])
                (loop (cdr specs) (append imports is) (append sources ss)))))]))))
