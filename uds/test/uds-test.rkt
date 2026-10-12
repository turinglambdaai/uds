#lang racket/base

;; Test suite for the uds package.  Golden values are anchored to the
;; public python-udsoncan implementation (MIT) — service IDs, NRCs, DTC
;; status bits — and to the ISO 14229-1 encoding rules (P2 timing units,
;; addressAndLengthFormatIdentifier, DTC text mapping).

(require rackunit
         racket/match
         uds/sid
         uds/nrc
         uds/dtc
         uds/request
         uds/response)

;; ---------------------------------------------------------------------------
;; Service IDs (values from python-udsoncan service files)

(test-case "service identifiers"
  (check-equal? sid:diagnostic-session-control #x10)
  (check-equal? sid:ecu-reset #x11)
  (check-equal? sid:clear-diagnostic-information #x14)
  (check-equal? sid:read-dtc-information #x19)
  (check-equal? sid:security-access #x27)
  (check-equal? sid:authentication #x29)
  (check-equal? sid:read-data-by-identifier #x22)
  (check-equal? sid:write-data-by-identifier #x2E)
  (check-equal? sid:input-output-control-by-identifier #x2F)
  (check-equal? sid:routine-control #x31)
  (check-equal? sid:request-download #x34)
  (check-equal? sid:transfer-data #x36)
  (check-equal? sid:request-transfer-exit #x37)
  (check-equal? sid:tester-present #x3E)
  (check-equal? sid:control-dtc-setting #x85)
  (check-equal? sid:link-control #x87)
  (check-equal? (service-name sid:read-data-by-identifier) 'read-data-by-identifier)
  (check-false (service-name #x77))
  (check-false (service-supported? #x77)))

(test-case "sub-function classification (python-udsoncan _use_subfunction)"
  (for ([sid (list sid:diagnostic-session-control sid:ecu-reset sid:read-dtc-information
                   sid:security-access sid:routine-control sid:tester-present
                   sid:control-dtc-setting sid:communication-control
                   sid:dynamically-define-data-identifier sid:read-data-by-periodic-identifier
                   sid:access-timing-parameter sid:response-on-event
                   sid:link-control sid:secured-data-transmission)])
    (check-true (service-uses-sub-function? sid) (format "~a should use sub-function" sid)))
  (for ([sid (list sid:clear-diagnostic-information sid:read-data-by-identifier
                   sid:write-data-by-identifier sid:read-memory-by-address
                   sid:write-memory-by-address sid:input-output-control-by-identifier
                   sid:request-download sid:request-upload sid:transfer-data
                   sid:request-transfer-exit sid:request-file-transfer
                   sid:read-scaling-data-by-identifier sid:authentication)])
    (check-false (service-uses-sub-function? sid) (format "~a should not use sub-function" sid))))

(test-case "suppress bit handling"
  (check-equal? (make-sub-function-byte #x03 #f) #x03)
  (check-equal? (make-sub-function-byte #x03 #t) #x83)
  (define-values (sub sup) (parse-sub-function-byte #x83))
  (check-equal? sub 3)
  (check-true sup)
  (define-values (sub2 sup2) (parse-sub-function-byte #x02))
  (check-equal? sub2 2)
  (check-false sup2))

;; ---------------------------------------------------------------------------
;; NRCs (values from python-udsoncan ResponseCode.py)

(test-case "negative response codes"
  (check-equal? nrc:general-reject #x10)
  (check-equal? nrc:service-not-supported #x11)
  (check-equal? nrc:sub-function-not-supported #x12)
  (check-equal? nrc:incorrect-message-length-or-invalid-format #x13)
  (check-equal? nrc:busy-repeat-request #x21)
  (check-equal? nrc:conditions-not-correct #x22)
  (check-equal? nrc:request-out-of-range #x31)
  (check-equal? nrc:security-access-denied #x33)
  (check-equal? nrc:invalid-key #x35)
  (check-equal? nrc:exceed-number-of-attempts #x36)
  (check-equal? nrc:required-time-delay-not-expired #x37)
  (check-equal? nrc:upload-download-not-accepted #x70)
  (check-equal? nrc:general-programming-failure #x72)
  (check-equal? nrc:wrong-block-sequence-counter #x73)
  (check-equal? nrc:request-correctly-received-response-pending #x78)
  (check-equal? nrc:sub-function-not-supported-in-active-session #x7E)
  (check-equal? nrc:service-not-supported-in-active-session #x7F)
  (check-equal? nrc:resource-temporarily-not-available #x94)
  ;; Reserved value deliberately absent from the table.
  (check-false (nrc-supported? #x23))
  (check-equal? (nrc-name nrc:request-out-of-range) 'request-out-of-range))

;; ---------------------------------------------------------------------------
;; Request builders

(test-case "diagnostic session control"
  (check-equal? (diagnostic-session-control 'default) (bytes #x10 #x01))
  (check-equal? (diagnostic-session-control 'programming) (bytes #x10 #x02))
  (check-equal? (diagnostic-session-control 'extended) (bytes #x10 #x03))
  (check-equal? (diagnostic-session-control 'extended #:suppress? #t) (bytes #x10 #x83))
  (check-equal? (diagnostic-session-control #x40) (bytes #x10 #x40)))

(test-case "ecu reset and tester present"
  (check-equal? (ecu-reset 'hard) (bytes #x11 #x01))
  (check-equal? (ecu-reset 'key-off-on) (bytes #x11 #x02))
  (check-equal? (ecu-reset 'soft) (bytes #x11 #x03))
  (check-equal? (tester-present) (bytes #x3E #x00))
  (check-equal? (tester-present #:suppress? #t) (bytes #x3E #x80)))

(test-case "read/write data by identifier"
  (check-equal? (read-data-by-identifier (list #xF190)) (bytes #x22 #xF1 #x90))
  (check-equal? (read-data-by-identifier (list #xF190 #x0100))
                (bytes #x22 #xF1 #x90 #x01 #x00))
  (check-exn exn:fail? (lambda () (read-data-by-identifier (list))))
  (check-equal? (write-data-by-identifier #xF190 (bytes 1 2 3))
                (bytes #x2E #xF1 #x90 1 2 3)))

(test-case "routine control"
  (check-equal? (routine-control 'start #x0203) (bytes #x31 #x01 #x02 #x03))
  (check-equal? (routine-control 'stop #x0203) (bytes #x31 #x02 #x02 #x03))
  (check-equal? (routine-control 'request-results #x0203 #:record (bytes #xAA))
                (bytes #x31 #x03 #x02 #x03 #xAA)))

(test-case "security access"
  (check-equal? (security-access-request-seed 1) (bytes #x27 #x01))
  (check-equal? (security-access-request-seed 3) (bytes #x27 #x03))
  (check-equal? (security-access-send-key 2 (bytes #x11 #x22 #x33 #x44))
                (bytes #x27 #x02 #x11 #x22 #x33 #x44))
  (check-exn exn:fail? (lambda () (security-access-request-seed 2)))  ; even level
  (check-exn exn:fail? (lambda () (security-access-send-key 1 #"")))  ; odd level
  (check-exn exn:fail? (lambda () (security-access-request-seed 0))))

(test-case "clear diagnostic information"
  (check-equal? (clear-diagnostic-information #xFFFFFF) (bytes #x14 #xFF #xFF #xFF))
  (check-equal? (clear-diagnostic-information #x012345) (bytes #x14 #x01 #x23 #x45)))

(test-case "read DTC information"
  (check-equal? (read-dtc-by-status-mask #x08) (bytes #x19 #x02 #x08))
  (check-equal? (report-number-of-dtc-by-status-mask #xFF) (bytes #x19 #x01 #xFF))
  (check-equal? (report-supported-dtc) (bytes #x19 #x0A)))

(test-case "download / transfer"
  ;; dataFormat 0x00, address 0x08001000 in 4 bytes, size 0x00010000 in 3
  ;; bytes => addressAndLengthFormatIdentifier 0x43.
  (check-equal? (request-download #x00 #x08001000 4 #x00010000 3)
                (bytes #x34 #x00 #x43 #x08 #x00 #x10 #x00 #x01 #x00 #x00))
  (check-equal? (transfer-data 1) (bytes #x36 #x01))
  (check-equal? (transfer-data 2 #:data (bytes 9 9)) (bytes #x36 #x02 9 9))
  (check-equal? (request-transfer-exit) (bytes #x37)))

(test-case "memory by address"
  (check-equal? (read-memory-by-address #x200015E0 4 #x0115 2)
                (bytes #x23 #x42 #x20 #x00 #x15 #xE0 #x01 #x15))
  (check-equal? (write-memory-by-address #x200015E0 4 (bytes #xAA #xBB))
                (bytes #x3D #x42 #x20 #x00 #x15 #xE0 #x00 #x02 #xAA #xBB)))

(test-case "address and length codec round trip"
  (define payload (encode-address-and-length #x08001000 4 #x00010000 3))
  (check-equal? (bytes-ref payload 0) #x43)
  (define-values (addr size) (decode-address-and-length payload))
  (check-equal? addr #x08001000)
  (check-equal? size #x00010000))

(test-case "request parse"
  (define r (request-parse (bytes #x10 #x03 #x12 #x34)))
  (check-equal? (request-sid r) sid:diagnostic-session-control)
  (check-equal? (request-sub-function r) 3)
  (check-false (request-suppress? r))
  (check-equal? (request-data r) (bytes #x12 #x34))
  (define r2 (request-parse (bytes #x10 #x83)))
  (check-true (request-suppress? r2))
  (check-equal? (request-sub-function r2) 3)
  (define r3 (request-parse (bytes #x22 #xF1 #x90)))
  (check-false (request-sub-function r3))
  (check-false (request-suppress? r3))
  (check-equal? (request-data r3) (bytes #xF1 #x90))
  (check-exn exn:fail? (lambda () (request-parse (bytes #x77))))
  (check-exn exn:fail? (lambda () (request-parse #"")))
  (check-exn exn:fail? (lambda () (request-parse (bytes #x10)))))

(test-case "make-request rejects sub-function misuse"
  (check-exn exn:fail? (lambda () (make-request sid:read-data-by-identifier
                                                #:sub-function 1)))
  (check-exn exn:fail? (lambda () (make-request sid:read-data-by-identifier
                                                #:suppress? #t))))

;; ---------------------------------------------------------------------------
;; DTC

(test-case "DTC text mapping (ISO 14229-1 16-bit layout)"
  (check-equal? (dtc-text->number "P0123") #x0123)
  (check-equal? (dtc-text->number "C1234") #x5234)
  (check-equal? (dtc-text->number "B2345") #xA345)
  (check-equal? (dtc-text->number "U3456") #xF456)
  (check-equal? (dtc-number->text #x0123) "P0123")
  (check-equal? (dtc-number->text #x4124) "C0124")
  (check-equal? (dtc-number->text #xF456) "U3456")
  (for ([text (list "P0123" "C0459" "B1234" "U3091")])
    (check-equal? (dtc-number->text (dtc-text->number text)) text))
  (check-exn exn:fail? (lambda () (dtc-text->number "X1234")))
  (check-exn exn:fail? (lambda () (dtc-text->number "P9123")))  ; first digit max 3
  (check-exn exn:fail? (lambda () (dtc-text->number "P012"))))

(test-case "DTC status byte (ISO 14229-1 Annex D)"
  (check-equal? (dtc-status->byte (make-dtc-status #:confirmed #t)) #x08)
  (check-equal? (dtc-status->byte (make-dtc-status #:test-failed #t)) #x01)
  (check-equal? (dtc-status->byte (make-dtc-status #:pending #t #:confirmed #t)) #x0C)
  (check-equal? (dtc-status->byte (make-dtc-status #:warning-indicator-requested #t)) #x80)
  ;; All flags set round trip.
  (define all
    (make-dtc-status #:test-failed #t
                     #:test-failed-this-operation-cycle #t
                     #:pending #t
                     #:confirmed #t
                     #:test-not-completed-since-last-clear #t
                     #:test-failed-since-last-clear #t
                     #:test-not-completed-this-operation-cycle #t
                     #:warning-indicator-requested #t))
  (check-equal? (dtc-status->byte all) #xFF)
  (check-equal? (dtc-status->byte (byte->dtc-status #x2C)) #x2C)
  (define s (byte->dtc-status #x2C))  ; pending + confirmed + failed-since-clear
  (check-false (dtc-status-test-failed s))
  (check-false (dtc-status-test-failed-this-operation-cycle s))
  (check-true (dtc-status-pending s))
  (check-true (dtc-status-confirmed s))
  (check-true (dtc-status-test-failed-since-last-clear s)))

(test-case "DTC wire records"
  (check-equal? (dtc-bytes #x0123 #x2C) (bytes #x01 #x23 #x2C))
  (define records (parse-dtc-records (bytes #x01 #x23 #x2C #x91 #x34 #x40)))
  (check-equal? (length records) 2)
  (check-equal? (dtc-number (car records)) #x0123)
  (check-equal? (dtc-status-byte (car records)) #x2C)
  (check-equal? (dtc-number (cadr records)) #x9134)
  (check-exn exn:fail? (lambda () (parse-dtc-records (bytes #x01 #x02)))))

;; ---------------------------------------------------------------------------
;; Responses

(test-case "response parse: positive with and without sub-function"
  (define r (response-parse (bytes #x50 #x03 #x00 #x32 #x00 #xC8)))
  (check-pred positive-response? r)
  (check-equal? (positive-response-sid r) sid:diagnostic-session-control)
  (check-equal? (positive-response-sub-function r) 3)
  (check-equal? (positive-response-data r) (bytes #x00 #x32 #x00 #xC8))
  (define r2 (response-parse (bytes #x62 #xF1 #x90 #x41 #x42)))
  (check-equal? (positive-response-sid r2) sid:read-data-by-identifier)
  (check-false (positive-response-sub-function r2))
  (check-equal? (positive-response-data r2) (bytes #xF1 #x90 #x41 #x42))
  (check-exn exn:fail? (lambda () (response-parse (bytes #x00))))
  (check-exn exn:fail? (lambda () (response-parse #""))))

(test-case "response parse: negative"
  (define r (response-parse (bytes #x7F #x22 #x31)))
  (check-pred negative-response? r)
  (check-equal? (negative-response-sid r) sid:read-data-by-identifier)
  (check-equal? (negative-response-nrc r) nrc:request-out-of-range)
  (check-true (response-pending? (bytes #x7F #x10 #x78)))
  (check-false (response-pending? (bytes #x7F #x10 #x31)))
  (check-equal? (negative-response-bytes sid:read-data-by-identifier
                                         nrc:request-out-of-range)
                (bytes #x7F #x22 #x31)))

(test-case "session control response timing (P2 in ms, P2* in units of 10 ms)"
  (define-values (session p2 p2-star)
    (session-control-response (bytes #x03 #x00 #x32 #x00 #xC8)))
  (check-equal? session 3)
  (check-equal? p2 50)                 ; 0x0032 ms
  (check-equal? p2-star 2000)          ; 0x00C8 * 10 ms
  (check-exn exn:fail? (lambda () (session-control-response (bytes #x03 #x00)))))

(test-case "security seed response"
  (check-equal? (security-seed-response (bytes #x04 #xDE #xAD #xBE #xEF))
                (bytes #xDE #xAD #xBE #xEF))
  (check-exn exn:fail? (lambda () (security-seed-response #""))))

(test-case "max block length response"
  (check-equal? (max-block-length-response (bytes #x08 #x00)) #x0800)
  (check-equal? (max-block-length-response (bytes #x00 #x0A)) 10)
  (check-exn exn:fail? (lambda () (max-block-length-response (bytes #x08 #x00 #xFF)))))

(test-case "number of DTC response"
  (define-values (fmt count) (number-of-dtc-response (bytes #x01 #x00 #x00 #x03)))
  (check-equal? fmt 1)
  (check-equal? count 3)
  (check-exn exn:fail? (lambda () (number-of-dtc-response (bytes #x01 #x00 #x00)))))

(test-case "DTC list response"
  (define dtcs (dtc-list-response (bytes #x01 #x23 #x2C #x91 #x34 #x40)))
  (check-equal? (length dtcs) 2)
  (check-equal? (dtc-number->text (dtc-number (car dtcs))) "P0123")
  (check-equal? (dtc-status-byte (cadr dtcs)) #x40))

(test-case "transfer data response"
  (define-values (counter data) (transfer-data-response (bytes #x01 #xAA #xBB)))
  (check-equal? counter 1)
  (check-equal? data (bytes #xAA #xBB))
  (check-exn exn:fail? (lambda () (transfer-data-response #""))))

(test-case "read DID list response"
  (check-equal? (did-list-response (bytes #xF1 #x90 #x01 #x00)) (list #xF190 #x0100))
  (check-exn exn:fail? (lambda () (did-list-response (bytes #xF1)))))

;; ---------------------------------------------------------------------------
;; End-to-end: request -> echo -> response classification

(test-case "round trip: a diagnostic exchange"
  (define req (diagnostic-session-control 'extended))
  (check-equal? (request-parse req)
                (request sid:diagnostic-session-control 3 #f #""))
  (define pos (response-parse (bytes-append (bytes (positive-sid sid:diagnostic-session-control) #x03)
                                            (bytes #x00 #x32 #x00 #xC8))))
  (check-equal? (positive-response-sub-function pos) 3)
  (define neg (response-parse (negative-response-bytes sid:diagnostic-session-control
                                                       nrc:conditions-not-correct)))
  (check-equal? (negative-response-nrc neg) nrc:conditions-not-correct))
