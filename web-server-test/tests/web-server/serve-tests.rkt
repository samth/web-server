#lang racket/base

(require net/http-client
         net/tcp-sig
         (prefix-in raw: net/tcp-unit)
         racket/async-channel
         racket/port
         racket/promise
         (prefix-in racket: racket/tcp)
         racket/unit
         rackunit
         version/utils
         web-server/http
         web-server/safety-limits
         web-server/servlet-dispatch
         web-server/web-server)

(provide
 serve-tests)

(define (call-with-web-server
         #:limits [limits (make-safety-limits #:shutdown-grace-period 5)]
         #:tcp@ [tcp@ raw:tcp@]
         handler proc)
  (define confirmation-ch
    (make-async-channel))
  (define stop
    (serve
     #:port 0
     #:dispatch (dispatch/servlet handler)
     #:confirmation-channel confirmation-ch
     #:safety-limits limits
     #:tcp@ tcp@))
  (define port-or-exn
    (sync confirmation-ch))
  (when (exn:fail? port-or-exn)
    (raise port-or-exn))
  (dynamic-wind
    void
    (lambda ()
      (proc port-or-exn stop))
    (lambda ()
      (stop))))

(define-check (check-duration proc lo hi timeout)
  (define promise
    (delay/thread
     (define-values (_ _cpu-time real-time _gc-time)
       (time-apply proc null))
     (/ real-time 1000)))
  (define real-time
    (sync/timeout
     timeout
     (handle-evt
      promise
      (lambda (_)
        (force promise)))))
  (unless real-time
    (fail-check "timed out"))
  (check-true
   (real-time . >= . lo)
   (format "took less than ~a seconds to run" lo))
  (check-true
   (real-time . <= . hi)
   (format "took more than ~a seconds to run" hi)))

(define serve-tests
  (test-suite
   "serve"

   (test-case "asks for a connection's addresses once"
     (define address-calls 0)
     (define-unit counting-tcp@
       (import)
       (export tcp^)
       (define (tcp-addresses p [port-numbers? #f])
         (set! address-calls (add1 address-calls))
         (racket:tcp-addresses p port-numbers?))
       (define tcp-connect racket:tcp-connect)
       (define tcp-connect/enable-break racket:tcp-connect/enable-break)
       (define tcp-listen racket:tcp-listen)
       (define tcp-accept racket:tcp-accept)
       (define tcp-accept/enable-break racket:tcp-accept/enable-break)
       (define tcp-accept-ready? racket:tcp-accept-ready?)
       (define tcp-close racket:tcp-close)
       (define tcp-listener? racket:tcp-listener?)
       (define tcp-abandon-port racket:tcp-abandon-port))
     (call-with-web-server
      #:tcp@ counting-tcp@
      (lambda (req)
        (response/full 200 #"OK" (current-seconds) #"text/plain" null
                       (list (string->bytes/utf-8 (request-client-ip req)))))
      (lambda (port _stop)
        (define hc (http-conn-open "127.0.0.1" #:port port))
        (for ([_ (in-range 3)])
          (define-values (status _headers in)
            (http-conn-sendrecv! hc "/"))
          (check-equal? status #"HTTP/1.1 200 OK")
          (check-equal? (port->bytes in) #"127.0.0.1"))
        (http-conn-close! hc)
        ;; one call for the listener's port and one for the connection
        (check-equal? address-calls 2))))

   (test-suite
    "graceful shutdown"

    (test-case "stops immediately if there are no connections"
      (call-with-web-server
       (lambda (_req)
         (response/empty))
       (lambda (_port stop)
         (check-duration stop 0 1 5))))

    ;; On versions prior to [1], net/http-client writes to standard
    ;; error when reading from the connection's input port goes wrong.
    ;; This makes raco test fail in --drdr mode, so avoid running these
    ;; tests on versions before 8.17.0.6.
    ;;
    ;; [1]: https://github.com/racket/racket/pull/5296
    (when (version<=? "8.17.0.6" (version))
      (test-case "waits for in-progress requests to finish"
        (call-with-web-server
         (lambda (_req)
           (response/output
            (lambda (out)
              (for ([idx (in-range 2)])
                (displayln idx out)
                (sleep 1)))))
         (lambda (port stop)
           (define hc (http-conn-open "127.0.0.1" #:port port))
           (define-values (status _headers in)
             (http-conn-sendrecv! hc "/"))
           (check-equal? status #"HTTP/1.1 200 OK")
           (check-duration stop 2 6 6)
           (check-equal? (port->bytes in) #"0\n1\n"))))

      (test-case "stops when in-progress requests stop"
        (call-with-web-server
         (lambda (_req)
           (response/output
            (lambda (out)
              (for ([idx (in-range 10)])
                (displayln idx out)
                (sleep 1)))))
         (lambda (port stop)
           (define hc (http-conn-open "127.0.0.1" #:port port))
           (define-values (status _headers in)
             (http-conn-sendrecv! hc "/"))
           (check-equal? status #"HTTP/1.1 200 OK")
           (thread
            (lambda ()
              (read-line in)
              (close-input-port in)
              (http-conn-close! hc)))
           (check-duration stop 1 3 5))))

      (test-case "kills the server if stop is called twice"
        (define started?-sema
          (make-semaphore))
        (call-with-web-server
         (lambda (_req)
           (response/output
            (lambda (out)
              (displayln "start" out)
              (semaphore-post started?-sema)
              (sleep 100)
              (displayln "end" out))))
         (lambda (port stop)
           (define hc (http-conn-open "127.0.0.1" #:port port))
           (define-values (status _headers in)
             (http-conn-sendrecv! hc "/"))
           (check-equal? status #"HTTP/1.1 200 OK")
           (define data-promise
             (delay/thread
              (with-handlers ([(lambda (e)
                                 (and (exn:fail? e)
                                      (regexp-match? #rx"input port is closed" (exn-message e))))
                               (lambda (_)
                                 #"")])
                (port->bytes in))))
           (semaphore-wait started?-sema)
           (define stop-thds
             (for/list ([_ (in-range 2)])
               (thread stop)))
           (check-duration
            (lambda ()
              (for-each thread-wait stop-thds))
            0 1 2)
           (check-match
            (force data-promise)
            (or #"" #"start\n")))))))))

(module+ test
  (require rackunit/text-ui)
  (run-tests serve-tests))
