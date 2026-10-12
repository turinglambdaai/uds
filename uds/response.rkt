#lang racket/base

;; UDS response parsing (ISO 14229-1).  A positive response is the request
;; SID | 0x40 followed (for sub-function services) by the echoed
;; sub-function and the response record; a negative response is 7F <SID>
;; <NRC> (see nrc.rkt).

(require racket/contract
         "sid.rkt"
         "nrc.rkt"
         "dtc.rkt"
         "request.rkt")

(provide (contract-out
          (struct positive-response ((sid (integer-in 0 255))
                                     (sub-function (or/c #f (integer-in 0 127)))
                                     (data bytes?)))
          [response-parse (-> bytes? (or/c positive-response? negative-response?))]
          [session-control-response
           (-> bytes? (values (integer-in 0 127) exact-nonnegative-integer? exact-nonnegative-integer?))]
          [security-seed-response (-> bytes? bytes?)]
          [max-block-length-response (-> bytes? (integer-in 0 65535))]
          [number-of-dtc-response
           (-> bytes? (values (integer-in 0 255) (integer-in 0 16777215)))]
          [dtc-list-response (-> bytes? (listof dtc?))]
          [transfer-data-response (-> bytes? (values (integer-in 0 255) bytes?))]
          [did-list-response (-> bytes? (listof (integer-in 0 65535)))]))

(struct positive-response (sid sub-function data) #:transparent)

(define (response-parse payload)
  (unless (>= (bytes-length payload) 1)
    (error 'response-parse "empty response payload"))
  (cond
    [(= (bytes-ref payload 0) #x7F)
     (negative-response-parse payload)]
    [(>= (bytes-ref payload 0) #x40)
     (define sid (response-sid->request-sid (bytes-ref payload 0)))
     (unless (service-supported? sid)
       (error 'response-parse "unknown service id #x~x in positive response" sid))
     (cond
       [(service-uses-sub-function? sid)
        (unless (>= (bytes-length payload) 2)
          (error 'response-parse "truncated sub-function in ~a response" (service-name sid)))
        (positive-response sid (bitwise-and (bytes-ref payload 1) #x7F) (subbytes payload 2))]
       [else
        (positive-response sid #f (subbytes payload 1))])]
    [else
     (error 'response-parse "not a UDS response: byte 0 is #x~x" (bytes-ref payload 0))]))

;; DiagnosticSessionControl positive response record: P2 server max time
;; (2 bytes, ms) then P2* (2 bytes, units of 10 ms).
(define (session-control-response data)
  (unless (>= (bytes-length data) 4)
    (error 'session-control-response "need 4 timing bytes, got ~a" (bytes-length data)))
  (values (bytes-ref data 0)
          (bytes->uint (subbytes data 1 3))       ; P2, milliseconds
          (* 10 (bytes->uint (subbytes data 3 5))))) ; P2*, units of 10 ms

;; SecurityAccess requestSeed positive response record: the seed bytes.
(define (security-seed-response data)
  (when (zero? (bytes-length data))
    (error 'security-seed-response "empty seed record"))
  (subbytes data 1))

;; RequestDownload/RequestUpload positive response record: the server's
;; maxNumberOfBlockLength (2 bytes in practice; the standard allows more).
(define (max-block-length-response data)
  (unless (>= (bytes-length data) 1)
    (error 'max-block-length-response "empty record"))
  (unless (<= (bytes-length data) 2)
    (error 'max-block-length-response
           "record longer than 2 bytes; interpret manually: ~a" data))
  (bytes->uint data))

;; ReadDTCInformation reportNumberOfDTCByStatusMask positive response
;; record: DTC format identifier byte, then the 24-bit count.
(define (number-of-dtc-response data)
  (unless (>= (bytes-length data) 4)
    (error 'number-of-dtc-response "need format + 3 count bytes, got ~a" (bytes-length data)))
  (values (bytes-ref data 0)
          (+ (* (bytes-ref data 1) 65536)
             (* (bytes-ref data 2) 256)
             (bytes-ref data 3))))

;; ReadDTCInformation reportDTCByStatusMask / reportSupportedDTC positive
;; response record: a run of 3-byte DTC records.
(define (dtc-list-response data)
  (parse-dtc-records data))

;; TransferData positive response record: echoed block sequence counter and
;; any response record data.
(define (transfer-data-response data)
  (unless (>= (bytes-length data) 1)
    (error 'transfer-data-response "empty record"))
  (values (bytes-ref data 0) (subbytes data 1)))

;; ReadDataByIdentifier positive response record: a run of (DID, data)
;; pairs; returns just the DID list.
(define (did-list-response data)
  (unless (zero? (remainder (bytes-length data) 2))
    (error 'did-list-response "expected DID pairs; use the raw data for payloads"))
  (for/list ([i (in-range 0 (bytes-length data) 2)])
    (+ (arithmetic-shift (bytes-ref data i) 8) (bytes-ref data (+ i 1)))))
