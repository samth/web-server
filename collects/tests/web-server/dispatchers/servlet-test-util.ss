#lang scheme/base
(require (planet "test.ss" ("schematics" "schemeunit.plt" 2))
         (planet "sxml.ss" ("lizorkin" "sxml.plt" 2 0))         
         mzlib/list
         web-server/http
         "../util.ss")
(provide test-add-two-numbers
         test-double-counters
         url0
         url0s)

(define url0 "http://test.com/servlets/example.ss")
(define url0s (list (build-path "servlets") (build-path "example.ss")))

(define (test-add-two-numbers mkd t p)
  (let* ([x (random 500)]
         [xs (string->bytes/utf-8 (number->string x))]
         [y (random 500)]
         [ys (string->bytes/utf-8 (number->string y))])
    (test-equal? 
     t
     (let* ([d (mkd p)]
            [k0 (first ((sxpath "//form/@action/text()") (call d url0 empty)))]
            [k1 (first ((sxpath "//form/@action/text()") (call d (format "~a?number=~a" k0 xs)
                                                               (list (make-binding:form #"number" xs)))))]
            [n (first ((sxpath "//p/text()") (call d (format "~a?number=~a" k1 ys)
                                                   (list (make-binding:form #"number" ys)))))])
       n)
     (format "The answer is ~a" (+ x y)))))

(define (test-double-counters mkd t p)
  (define d (mkd p))
  (define (invoke u)
    (define sx (call d u empty))
    (define ks ((sxpath "//div/div/a/@href/text()") sx))
    (values ((sxpath "//div/div/h3/text()") sx)
            (first ks)
            (second ks)))
  (test-equal? t
               (let*-values ([(v0.0 0.0+1 0.0+2) (invoke url0)]
                             ; One add
                             [(v1.0 1.0+1 1.0+2) (invoke 0.0+1)] ; XXX infinite loop after this
                             [(v0.1 0.1+1 0.1+2) (invoke 0.0+2)]
                             ; Two adds
                             [(v2.0 2.0+1 2.0+2) (invoke 1.0+1)]
                             [(v1.1 1.1+1 1.1+2) (invoke 0.1+1)]
                             [(_v1.1 _1.1+1 _1.1+2) (invoke 1.0+2)]
                             [(v0.2 0.2+1 0.2+2) (invoke 0.1+2)])
                 (list v0.0
                       v1.0 v0.1
                       v2.0 v1.1 _v1.1 v0.2))
               (list (list "0" "0")
                     (list "1" "0") (list "0" "1")
                     (list "2" "0") (list "1" "1") (list "1" "1") (list "0" "2"))))