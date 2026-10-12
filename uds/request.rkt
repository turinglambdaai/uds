#lang racket/base

;; UDS request construction and parsing (ISO 14229-1).  Every builder
;; returns the payload bytes of one ISO-TP message; nothing here talks to a
;; transport.

(require racket/contract
         "sid.rkt"
         "dtc.rkt")

(provide (contract-out
          (struct request ((sid (integer-in 0 255))
                           (sub-function (or/c #f (integer-in 0 127)))
                           (suppress? boolean?)
                           (data bytes?)))
          [make-request
           (->* ((integer-in 0 255))
                (#:sub-function (or/c #f (integer-in 0 127))
                 #:suppress? boolean?
                 #:data bytes?)
                bytes?)]
          [request-parse (-> bytes? request?)]
          [diagnostic-session-control
           (->* ((or/c 'default 'programming 'extended (integer-in 0 127)))
                (#:suppress? boolean?)
                bytes?)]
          [ecu-reset
           (->* ((or/c 'hard 'key-off-on 'soft (integer-in 0 127)))
                (#:suppress? boolean?)
                bytes?)]
          [tester-present (->* () (#:suppress? boolean?) bytes?)]
          [control-dtc-setting
           (->* ((or/c 'on 'off (integer-in 0 127)))
                (#:suppress? boolean? #:data bytes?)
                bytes?)]
          [clear-diagnostic-information (-> (integer-in 0 16777215) bytes?)]
          [read-dtc-by-status-mask (-> (integer-in 0 255) bytes?)]
          [report-number-of-dtc-by-status-mask (-> (integer-in 0 255) bytes?)]
          [report-supported-dtc (->* () (#:suppress? boolean?) bytes?)]
          [security-access-request-seed (-> (integer-in 0 63) bytes?)]
          [security-access-send-key (-> (integer-in 0 63) bytes? bytes?)]
          [communication-control
           (->* ((or/c 'enable-rx-and-tx 'enable-tx-disable-rx
                       'disable-tx-enable-rx 'disable-rx-and-tx
                       (integer-in 0 127)))
                (#:suppress? boolean? #:data bytes?)
                bytes?)]
          [read-data-by-identifier (-> (listof (integer-in 0 65535)) bytes?)]
          [write-data-by-identifier
           (-> (integer-in 0 65535) bytes? bytes?)]
          [read-memory-by-address
           (-> (integer-in 0 18446744073709551615)
               (integer-in 1 15)
               (integer-in 0 18446744073709551615)
               (integer-in 1 15)
               bytes?)]
          [write-memory-by-address
           (-> (integer-in 0 18446744073709551615)
               (integer-in 1 15)
               bytes?
               bytes?)]
          [routine-control
           (->* ((or/c 'start 'stop 'request-results (integer-in 0 127))
                 (integer-in 0 65535))
                (#:record bytes? #:suppress? boolean?)
                bytes?)]
          [input-output-control-by-identifier
           (-> (integer-in 0 65535) bytes? bytes?)]
          [request-download
           (-> (integer-in 0 255)
               (integer-in 0 18446744073709551615)
               (integer-in 1 15)
               (integer-in 0 18446744073709551615)
               (integer-in 1 15)
               bytes?)]
          [transfer-data (->* ((integer-in 0 255)) (#:data bytes?) bytes?)]
          [request-transfer-exit (->* () (#:data bytes?) bytes?)]
          [encode-address-and-length
           (-> (integer-in 0 18446744073709551615) (integer-in 1 15)
               (integer-in 0 18446744073709551615) (integer-in 1 15)
               bytes?)]
          [decode-address-and-length
           (-> bytes? (values (integer-in 0 18446744073709551615)
                              (integer-in 0 18446744073709551615)))]
          [uint->bytes (-> (integer-in 0 18446744073709551615) (integer-in 1 8) bytes?)]
          [bytes->uint (-> bytes? (integer-in 0 18446744073709551615))]
          [did->bytes (-> (integer-in 0 65535) bytes?)]))

(struct request (sid sub-function suppress? data) #:transparent)

;; ---------------------------------------------------------------------------
;; Generic framing

(define (make-request sid
                      #:sub-function [sub #f]
                      #:suppress? [suppress? #f]
                      #:data [data #""])
  (define sub-byte
    (cond [(service-uses-sub-function? sid)
           (make-sub-function-byte (or sub 0) suppress?)]
          [(or sub suppress?)
           (error 'make-request
                  "service ~a does not use sub-functions; got sub ~a suppress ~a"
                  (or (service-name sid) sid) sub suppress?)]
          [else #f]))
  (if sub-byte
      (bytes-append (bytes sid sub-byte) data)
      (bytes-append (bytes sid) data)))

;; Parses any request payload.  For sub-function services the second byte is
;; decoded into the sub-function and the suppress bit; for the others the
;; whole tail is data.
(define (request-parse payload)
  (unless (>= (bytes-length payload) 1)
    (error 'request-parse "empty request payload"))
  (define sid (bytes-ref payload 0))
  (unless (service-supported? sid)
    (error 'request-parse "unknown service id #x~x" sid))
  (cond
    [(service-uses-sub-function? sid)
     (unless (>= (bytes-length payload) 2)
       (error 'request-parse "truncated sub-function byte in ~a request" (service-name sid)))
     (define-values (sub suppress?) (parse-sub-function-byte (bytes-ref payload 1)))
     (request sid sub suppress? (subbytes payload 2))]
    [else
     (request sid #f #f (subbytes payload 1))]))

;; ---------------------------------------------------------------------------
;; Small helpers

(define (did->bytes did)
  (bytes (bitwise-and (arithmetic-shift did -8) #xFF) (bitwise-and did #xFF)))

(define (uint->bytes v nbytes)
  (list->bytes
   (for/list ([i (in-range (sub1 nbytes) -1 -1)])
     (bitwise-and (arithmetic-shift v (* -8 i)) #xFF))))

(define (bytes->uint bs)
  (for/fold ([v 0]) ([b (in-bytes bs)])
    (+ (arithmetic-shift v 8) b)))

;; addressAndLengthFormatIdentifier: high nibble = address byte count,
;; low nibble = size byte count.
(define (encode-address-and-length address address-bytes size size-bytes)
  (bytes-append (bytes (bitwise-ior (arithmetic-shift address-bytes 4) size-bytes))
                (uint->bytes address address-bytes)
                (uint->bytes size size-bytes)))

(define (decode-address-and-length payload)
  (unless (>= (bytes-length payload) 1)
    (error 'decode-address-and-length "missing format identifier"))
  (define fmt (bytes-ref payload 0))
  (define addr-bytes (arithmetic-shift fmt -4))
  (define size-bytes (bitwise-and fmt #x0F))
  (unless (>= (bytes-length payload) (+ 1 addr-bytes size-bytes))
    (error 'decode-address-and-length "payload too short for format #x~x" fmt))
  (values (bytes->uint (subbytes payload 1 (+ 1 addr-bytes)))
          (bytes->uint (subbytes payload (+ 1 addr-bytes) (+ 1 addr-bytes size-bytes)))))

;; ---------------------------------------------------------------------------
;; Typed builders

(define (session-byte v)
  (case v
    [(default) 1]
    [(programming) 2]
    [(extended) 3]
    [else v]))

(define (diagnostic-session-control type #:suppress? [suppress? #f])
  (make-request sid:diagnostic-session-control
                #:sub-function (session-byte type)
                #:suppress? suppress?))

(define (reset-byte v)
  (case v
    [(hard) 1]
    [(key-off-on) 2]
    [(soft) 3]
    [else v]))

(define (ecu-reset type #:suppress? [suppress? #f])
  (make-request sid:ecu-reset #:sub-function (reset-byte type) #:suppress? suppress?))

(define (tester-present #:suppress? [suppress? #f])
  (make-request sid:tester-present #:sub-function 0 #:suppress? suppress?))

(define (control-dtc-setting mode #:suppress? [suppress? #f] #:data [data #""])
  (define sub (case mode [(on) 1] [(off) 2] [else mode]))
  (make-request sid:control-dtc-setting #:sub-function sub #:suppress? suppress? #:data data))

(define (clear-diagnostic-information group)
  (make-request sid:clear-diagnostic-information #:data (dtc-group-bytes group)))

(define (read-dtc-by-status-mask mask)
  (make-request sid:read-dtc-information #:sub-function #x02 #:data (bytes mask)))

(define (report-number-of-dtc-by-status-mask mask)
  (make-request sid:read-dtc-information #:sub-function #x01 #:data (bytes mask)))

;; subFunction 0x0A carries no extra parameters.
(define (report-supported-dtc #:suppress? [suppress? #f])
  (make-request sid:read-dtc-information #:sub-function #x0A #:suppress? suppress?))

;; SecurityAccess levels pair up: 0x01/0x02, 0x03/0x04, ...  Odd numbers
;; request a seed, the next even number sends the key for that level.
(define (check-security-level level)
  (unless (<= 1 level 63)
    (error 'security-access "security level must be 1-63, got ~a" level)))

(define (security-access-request-seed level)
  (check-security-level level)
  (unless (odd? level)
    (error 'security-access "request-seed takes an odd level (the seed level), got ~a" level))
  (make-request sid:security-access #:sub-function level))

(define (security-access-send-key level key)
  (check-security-level level)
  (unless (even? level)
    (error 'security-access "send-key takes an even level (the key level), got ~a" level))
  (make-request sid:security-access #:sub-function level #:data key))

(define (communication-control mode #:suppress? [suppress? #f] #:data [data #""])
  (define sub
    (case mode
      [(enable-rx-and-tx) 0]
      [(enable-tx-disable-rx) 1]
      [(disable-tx-enable-rx) 2]
      [(disable-rx-and-tx) 3]
      [else mode]))
  (make-request sid:communication-control #:sub-function sub #:suppress? suppress? #:data data))

;; One or more 16-bit data identifiers in one request.
(define (read-data-by-identifier dids)
  (when (null? dids)
    (error 'read-data-by-identifier "at least one DID is required"))
  (make-request sid:read-data-by-identifier
                #:data (apply bytes-append (map did->bytes dids))))

(define (write-data-by-identifier did data)
  (make-request sid:write-data-by-identifier #:data (bytes-append (did->bytes did) data)))

(define (read-memory-by-address address address-bytes size size-bytes)
  (make-request sid:read-memory-by-address
                #:data (encode-address-and-length address address-bytes size size-bytes)))

(define (write-memory-by-address address address-bytes data)
  (define size-bytes (max 1 (integer-length (bytes-length data))))
  (unless (<= size-bytes 15)
    (error 'write-memory-by-address "data too large to encode"))
  (make-request sid:write-memory-by-address
                #:data (bytes-append (encode-address-and-length
                                      address address-bytes (bytes-length data) size-bytes)
                                     data)))

(define (routine-byte v)
  (case v
    [(start) 1]
    [(stop) 2]
    [(request-results) 3]
    [else v]))

(define (routine-control action routine-id #:record [record #""] #:suppress? [suppress? #f])
  (make-request sid:routine-control
                #:sub-function (routine-byte action)
                #:suppress? suppress?
                #:data (bytes-append (did->bytes routine-id) record)))

(define (input-output-control-by-identifier did data)
  (make-request sid:input-output-control-by-identifier
                #:data (bytes-append (did->bytes did) data)))

(define (request-download data-format-id address address-bytes size size-bytes)
  (make-request sid:request-download
                #:data (bytes-append (bytes data-format-id)
                                     (encode-address-and-length
                                      address address-bytes size size-bytes))))

(define (transfer-data counter #:data [data #""])
  (make-request sid:transfer-data #:data (bytes-append (bytes counter) data)))

(define (request-transfer-exit #:data [data #""])
  (make-request sid:request-transfer-exit #:data data))
