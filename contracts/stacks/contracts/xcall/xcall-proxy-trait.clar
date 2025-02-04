(use-trait xcall-impl-trait .xcall-impl-trait.xcall-impl-trait)
(use-trait xcall-common-trait .xcall-common-trait.xcall-common-trait)
(use-trait xcall-receiver-trait .xcall-receiver-trait.xcall-receiver-trait)

(define-trait xcall-proxy-trait
  (
    (get-current-implementation () (response principal bool))
    (get-current-proxy () (response (optional principal) uint))
    
    (is-current-implementation (principal) (response bool uint))

    (send-call ((string-ascii 128) (buff 2048) <xcall-impl-trait>) (response uint uint))

    (send-call-message ((string-ascii 128) (buff 2048) (optional (buff 1024)) (optional (list 10 (string-ascii 128))) (optional (list 10 (string-ascii 128))) <xcall-common-trait>) (response uint uint))

    (execute-call (uint (buff 2048) <xcall-receiver-trait> <xcall-common-trait> <xcall-impl-trait>) (response bool uint))

    (execute-rollback (uint <xcall-receiver-trait> <xcall-common-trait> <xcall-impl-trait>) (response bool uint))

    (verify-success (uint <xcall-impl-trait>) (response bool uint))

    (handle-message ((string-ascii 128) (buff 2048) <xcall-impl-trait>) (response bool uint))

    (handle-error (uint <xcall-impl-trait>) (response bool uint))

    (set-admin (principal <xcall-impl-trait>) (response bool uint))

    (set-protocol-fee-handler (principal <xcall-impl-trait>) (response bool uint))

    (set-protocol-fee (uint <xcall-impl-trait>) (response bool uint))

    (set-default-connection ((string-ascii 128) (string-ascii 128) <xcall-impl-trait>) (response bool uint))

    (set-trusted-protocols ((string-ascii 128) (list 10 (string-ascii 128)) <xcall-impl-trait>) (response bool uint))

    (get-network-address (<xcall-common-trait>) (response (string-ascii 257) uint))

    (get-network-id (<xcall-impl-trait>) (response (string-ascii 128) uint))

    (get-protocol-fee (<xcall-impl-trait>) (response uint uint))

    (get-fee ((string-ascii 128) bool (optional (list 10 (string-ascii 128))) <xcall-impl-trait>) (response uint uint))
  )
)