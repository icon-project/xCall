(use-trait xcall-receiver-trait .xcall-receiver-trait.xcall-receiver-trait)
(use-trait xcall-common-trait .xcall-common-trait.xcall-common-trait)

(define-trait xcall-impl-trait
  (
    (send-call ((string-ascii 128) (buff 2048)) (response uint uint))
  
    (execute-call (uint (buff 2048) <xcall-receiver-trait> <xcall-common-trait>) (response bool uint))
    (execute-rollback (uint <xcall-receiver-trait> <xcall-common-trait>) (response bool uint))
    
    (verify-success (uint) (response bool uint))

    (handle-message ((string-ascii 128) (buff 2048)) (response bool uint))
    (handle-error (uint) (response bool uint))
    
    (set-admin (principal) (response bool uint))
    (set-protocol-fee-handler (principal) (response bool uint))
    (set-protocol-fee (uint) (response bool uint))
    (set-default-connection ((string-ascii 128) (string-ascii 128)) (response bool uint))
    (set-trusted-protocols ((string-ascii 128) (list 10 (string-ascii 128))) (response bool uint))
    
    (get-network-id () (response (string-ascii 128) uint))
    (get-protocol-fee () (response uint uint))
    (get-fee ((string-ascii 128) bool (optional (list 10 (string-ascii 128)))) (response uint uint))
  )
)