#lang racket/base
;; Synthetic UDS payload example. No vehicle, CAN device or secrets required.
(require uds)

(unless (bytes=? (diagnostic-session-control 'extended) (bytes #x10 #x03))
  (error 'uds-quickstart "extended diagnostic-session request mismatch"))
(unless (bytes=? (read-data-by-identifier (list #xF190)) (bytes #x22 #xF1 #x90))
  (error 'uds-quickstart "VIN DID request mismatch"))

;; The positive-response parser separates the echoed sub-function from the
;; timing bytes; session-control-response expects both in its input record.
(define parsed (response-parse (bytes #x50 #x03 #x00 #x32 #x00 #xC8)))
(unless (and (positive-response? parsed)
             (= (positive-response-sub-function parsed) 3))
  (error 'uds-quickstart "session echo is missing"))
(define timing-record
  (bytes-append (bytes (positive-response-sub-function parsed))
                (positive-response-data parsed)))
(define-values (session p2-ms p2-star-ms)
  (session-control-response timing-record))
(unless (equal? (list session p2-ms p2-star-ms) '(3 50 2000))
  (error 'uds-quickstart "session timing decoding mismatch"))

(define refused (response-parse (bytes #x7F #x22 #x31)))
(unless (and (negative-response? refused)
             (= (negative-response-sid refused) #x22)
             (= (negative-response-nrc refused) #x31))
  (error 'uds-quickstart "negative response decoding mismatch"))
(unless (= (dtc-text->number "P0123") #x0123)
  (error 'uds-quickstart "DTC encoding mismatch"))

(displayln "UDS message-layer quickstart OK")
