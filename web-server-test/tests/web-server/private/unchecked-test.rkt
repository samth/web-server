#lang racket/base
(require rackunit
         racket/contract
         racket/list
         racket/path
         racket/file)
(provide unchecked-tests)

;; Modules that provide an `unchecked` submodule for web-server's own use must
;; still export contracted bindings: the submodule holds the only unchecked copies.
(define web-server-dir
  (path-only (collection-file-path "web-server.rkt" "web-server")))

(define modules-with-unchecked
  (for/list ([f (in-directory web-server-dir)]
             #:when (regexp-match? #rx"[.]rkt$" (path->string f))
             #:unless (regexp-match? #rx"/compiled/|/private/unchecked[.]rkt$" (path->string f))
             #:when (regexp-match? #rx"#:unprotected-submodule unchecked|\\(module unchecked "
                                   (file->string f)))
    f))

(define (phase-0-exports mod)
  (dynamic-require mod (void))
  (define-values (vars stxs) (module->exports mod))
  (for*/list ([phase+names (in-list (append vars stxs))]
              #:when (eqv? (car phase+names) 0)
              [name (in-list (cdr phase+names))])
    (car name)))

(define unchecked-tests
  (test-suite
   "unchecked submodules"
   (test-true "some modules have an unchecked submodule"
              (> (length modules-with-unchecked) 20))
   ;; Representative public bindings, including ones re-exported by aggregate modules
   (for ([mod+name (in-list '((web-server/http request-method)
                              (web-server/http response/full)
                              (web-server/http headers-assq*)
                              (web-server/http/response output-response)
                              (web-server/servlet send/suspend)
                              (web-server/servlet-env serve/servlet)
                              (web-server/servlet-dispatch dispatch/servlet)
                              (web-server/web-server serve)
                              (web-server/dispatchers/dispatch make-exn:dispatcher)
                              (web-server/dispatchers/dispatch-files make)
                              (web-server/managers/lru make-threshold-LRU-manager)
                              (web-server/private/connection-manager connection-o-port)))])
     (check-true (has-contract? (dynamic-require (car mod+name) (cadr mod+name)))
                 (format "~a from ~a" (cadr mod+name) (car mod+name))))
   (for ([f (in-list modules-with-unchecked)])
     (define sub `(submod ,f unchecked))
     (define main-names (phase-0-exports f))
     (for ([name (in-list (phase-0-exports sub))]
           #:when (memq name main-names))
       (define checked (dynamic-require f name (λ () #f)))
       (define unchecked (dynamic-require sub name (λ () #f)))
       (when (and (has-contract? unchecked) (not (has-contract? checked)))
         (fail (format "~a: ~a lost its contract" f name)))
       (when (and (procedure? checked) (not (eq? checked unchecked)))
         (check-true (has-contract? checked)
                     (format "~a: ~a should be contracted" f name)))))))

(module+ test
  (require rackunit/text-ui)
  (run-tests unchecked-tests))
