(use-trait xcall-impl-trait .xcall-impl-trait.xcall-impl-trait)

(define-constant ERR_UNAUTHORIZED (err u900))
(define-constant ERR_INVALID_FEE (err u901))
(define-constant ERR_DUPLICATE_MESSAGE (err u902))
(define-constant ERR_XCALL_NOT_SET (err u903))

(define-data-var xcall (optional principal) none)
(define-data-var admin principal tx-sender)
(define-data-var conn-sn int 0)

(define-map message-fees {network-id: (string-ascii 128)} uint)
(define-map response-fees {network-id: (string-ascii 128)} uint)
(define-map receipts {network-id: (string-ascii 128), conn-sn: int} bool)

(define-read-only (get-xcall)
  (ok (var-get xcall)))

(define-read-only (get-admin)
  (ok (var-get admin)))

(define-read-only (get-conn-sn)
  (ok (var-get conn-sn)))

(define-read-only (get-fee (to (string-ascii 128)) (response bool))
  (let
    ((message-fee (default-to u0 (map-get? message-fees {network-id: to}))))
    (if response
      (let
        ((response-fee (default-to u0 (map-get? response-fees {network-id: to}))))
        (ok (+ message-fee response-fee)))
      (ok message-fee))))

(define-read-only (get-receipt (src-network (string-ascii 128)) (conn-sn-in int))
  (ok (default-to false (map-get? receipts {network-id: src-network, conn-sn: conn-sn-in}))))

(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

(define-private (is-xcall)
  (match (var-get xcall)
    xcall-contract (is-eq tx-sender xcall-contract)
    false
  ))

(define-private (is-authorized)
  (or 
    (is-xcall)
    (is-admin)))

(define-public (initialize (xcall-contract principal) (admin-address principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set xcall (some xcall-contract))
    (var-set admin admin-address)
    (ok true)))

(define-public (set-fee (network-id (string-ascii 128)) (message-fee uint) (response-fee uint))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (map-set message-fees {network-id: network-id} message-fee)
    (map-set response-fees {network-id: network-id} response-fee)
    (ok true)))

(define-public (claim-fees)
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (as-contract (stx-transfer? (stx-get-balance (as-contract tx-sender)) tx-sender (var-get admin)))))

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-private (emit-message-event (to (string-ascii 128)) (sn int) (msg (buff 2048)))
  (print 
    {
      event: "Message",
      to: to,
      sn: sn,
      msg: msg
    }
  )
)

(define-public (send-message (to (string-ascii 128)) (svc (string-ascii 128)) (sn int) (msg (buff 2048)))
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (let
      ((fee (unwrap! (get-fee to (> sn 0)) ERR_INVALID_FEE)))
      (asserts! (>= (stx-get-balance tx-sender) fee) ERR_INVALID_FEE)
      (var-set conn-sn (+ (var-get conn-sn) 1))
      (emit-message-event to (var-get conn-sn) msg)
      (ok (var-get conn-sn)))))

(define-public (recv-message (src-network-id (string-ascii 128)) (conn-sn-in int) (msg (buff 2048)) (implementation <xcall-impl-trait>))
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? receipts {network-id: src-network-id, conn-sn: conn-sn-in})) ERR_DUPLICATE_MESSAGE)
    (map-set receipts {network-id: src-network-id, conn-sn: conn-sn-in} true)
    (as-contract (contract-call? .xcall-proxy handle-message src-network-id msg implementation))))