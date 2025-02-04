(impl-trait .xcall-proxy-trait.xcall-proxy-trait)
(use-trait xcall-impl-trait .xcall-impl-trait.xcall-impl-trait)
(use-trait xcall-common-trait .xcall-common-trait.xcall-common-trait)
(use-trait xcall-receiver-trait .xcall-receiver-trait.xcall-receiver-trait)

(define-constant CONTRACT_NAME "xcall-proxy")

(define-data-var contract-owner principal tx-sender)
(define-data-var current-logic-implementation principal tx-sender)
(define-data-var current-proxy (optional principal) none)

(define-constant err-not-current-implementation (err u100))
(define-constant err-not-owner (err u101))

(define-map data-storage (string-ascii 16) (buff 2048))

;; xcall-proxy-trait implementation

(define-read-only (get-current-implementation)
    (ok (var-get current-logic-implementation))
)

(define-read-only (get-current-proxy)
    (ok (var-get current-proxy))
)

(define-read-only (is-current-implementation (implementation principal))
    (ok (is-eq implementation (var-get current-logic-implementation)))
)

(define-public (set-trusted-protocols (nid (string-ascii 128)) (protocols (list 10 (string-ascii 128))) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation set-trusted-protocols nid protocols)
    )
)

(define-public (send-call (to (string-ascii 128)) (data (buff 2048)) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation send-call to data)
    )
)

(define-public (send-call-message (to (string-ascii 128)) (data (buff 2048)) (rollback (optional (buff 1024))) (sources (optional (list 10 (string-ascii 128)))) (destinations (optional (list 10 (string-ascii 128)))) (implementation <xcall-common-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation send-call-message to data rollback sources destinations)
    )
)

(define-public (execute-call (req-id uint) (data (buff 2048)) (receiver <xcall-receiver-trait>) (common <xcall-common-trait>) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (as-contract (contract-call? implementation execute-call req-id data receiver common))
    )
)

(define-public (execute-rollback (sn uint) (receiver <xcall-receiver-trait>) (common <xcall-common-trait>) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (as-contract (contract-call? implementation execute-rollback sn receiver common))
    )
)

(define-public (verify-success (sn uint) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation verify-success sn)
    )
)

(define-public (handle-message (source-network (string-ascii 128)) (message (buff 2048)) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation handle-message source-network message)
    )
)

(define-public (handle-error (sn uint) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation handle-error sn)
    )
)

;; Admin methods

(define-public (set-admin (new-admin principal) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation set-admin new-admin)
    )
)

(define-public (set-protocol-fee-handler (handler principal) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation set-protocol-fee-handler handler)
    )
)

(define-public (set-protocol-fee (fee uint) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation set-protocol-fee fee)
    )
)

(define-public (set-default-connection (nid (string-ascii 128)) (connection (string-ascii 128)) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation set-default-connection nid connection)
    )
)

;; Read-only methods

(define-public (get-network-address (implementation <xcall-common-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation get-network-address)
    )
)

(define-public (get-network-id (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation get-network-id)
    )
)

(define-public (get-protocol-fee (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation get-protocol-fee)
    )
)

(define-public (get-fee (net (string-ascii 128)) (rollback bool) (sources (optional (list 10 (string-ascii 128)))) (implementation <xcall-impl-trait>))
    (begin
        (asserts! (is-eq (contract-of implementation) (var-get current-logic-implementation)) err-not-current-implementation)
        (contract-call? implementation get-fee net rollback sources)
    )
)

;; Governance functions

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (is-contract-owner (who principal))
    (is-eq who (var-get contract-owner))
)

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-contract-owner contract-caller) err-not-owner)
        (ok (var-set contract-owner new-owner))
    )
)

(define-public (upgrade (new-implementation <xcall-impl-trait>) (new-proxy (optional principal)))
    (begin
        ;; (asserts! (is-contract-owner contract-caller) err-not-owner)
        (var-set current-proxy new-proxy)
        (ok (var-set current-logic-implementation (contract-of new-implementation)))
    )
)

;; Implementation functions to affect contract storage

(define-read-only (get-data (key (string-ascii 16)))
    (map-get? data-storage key)
)

(define-public (set-data (key (string-ascii 16)) (value (buff 2048)))
    (begin
        (asserts! (is-eq contract-caller (var-get current-logic-implementation)) err-not-current-implementation)
        (ok (map-set data-storage key value))
    )
)