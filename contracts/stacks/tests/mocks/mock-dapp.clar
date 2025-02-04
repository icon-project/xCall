(use-trait xcall-common-trait .xcall-common-trait.xcall-common-trait)
(impl-trait .xcall-receiver-trait.xcall-receiver-trait)

(define-constant ERR_UNAUTHORIZED (err u800))
(define-constant ERR_INVALID_PROTOCOL (err u801))
(define-constant ERR_INVALID_MESSAGE (err u802))
(define-constant ERR_RLP_DECODE (err u803))

(define-data-var call-service principal tx-sender)

(define-map sources {nid: (string-ascii 128)} (list 10 (string-ascii 128)))
(define-map destinations {nid: (string-ascii 128)} (list 10 (string-ascii 128)))

(define-public (initialize (call-svc principal))
  (begin
    (var-set call-service call-svc)
    (ok true)))

(define-private (is-call-service)
  (is-eq tx-sender (var-get call-service)))

(define-public (add-connection (nid (string-ascii 128)) (source (string-ascii 128)) (destination (string-ascii 128)))
  (begin
    (map-set sources {nid: nid} 
      (unwrap! (as-max-len? (append (default-to (list) (map-get? sources {nid: nid})) source) u10) ERR_INVALID_PROTOCOL))
    (map-set destinations {nid: nid} 
      (unwrap! (as-max-len? (append (default-to (list) (map-get? destinations {nid: nid})) destination) u10) ERR_INVALID_PROTOCOL))
    (ok true)))

(define-read-only (get-sources (nid (string-ascii 128)))
  (default-to (list) (map-get? sources {nid: nid})))

(define-read-only (get-destinations (nid (string-ascii 128)))
  (default-to (list) (map-get? destinations {nid: nid})))

(define-public (send-message (to (string-ascii 128)) (data (buff 2048)) (rollback (optional (buff 1024))) (xcall-common <xcall-common-trait>))
  (let
    (
      (net (unwrap! (slice? to u0 (unwrap-panic (index-of to "/"))) ERR_INVALID_MESSAGE))
      (sources-list (get-sources net))
      (destinations-list (get-destinations net))
    )
    (contract-call? .xcall-proxy send-call-message to data rollback (some sources-list) (some destinations-list) xcall-common)))

(define-private (decode-rlp-message (data (buff 2048)))
  (let
    (
      (message (unwrap-panic (as-max-len? (unwrap-panic (slice? data u1 (len data))) u2048))) ;; Drop RLP prefix byte
    )
    (ok (unwrap-panic (contract-call? .rlp-decode decode-string message)))))

(define-public (handle-call-message (from (string-ascii 128)) (data (buff 2048)) (protocols (list 10 (string-ascii 128))) (xcall-common <xcall-common-trait>))
  (begin
    ;; (asserts! (is-call-service) ERR_UNAUTHORIZED)
    (let
      (
        (from-net (unwrap! (slice? from u0 (unwrap-panic (index-of from "/"))) ERR_INVALID_MESSAGE))
        (rollback-address (unwrap! (contract-call? .xcall-proxy get-network-address xcall-common) ERR_INVALID_MESSAGE))
        (decoded-message (unwrap! (decode-rlp-message data) ERR_INVALID_MESSAGE))
      )
      (if (is-eq rollback-address from)
        (print {event: "RollbackReceived", from: from, data: decoded-message})
        (begin
          (asserts! (or 
            (is-eq protocols (get-sources from-net))
            (and (is-eq (len protocols) u0) (> (len (get-sources from-net)) u0))
          ) 
          ERR_INVALID_PROTOCOL)
          (asserts! (not (is-eq decoded-message "rollback")) ERR_INVALID_MESSAGE)
          (if (is-eq decoded-message "reply-response")
            (begin
              (try! (send-message from 0x010203 none xcall-common))
              (print {event: "ReplyResponseSent", from: from, data: decoded-message})
            )
            (print {event: "MessageReceived", from: from, data: decoded-message})
          )
        )
      )
      (ok true)
    )
  ))
