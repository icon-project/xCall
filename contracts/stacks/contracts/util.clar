(define-constant C32SET "0123456789ABCDEFGHJKMNPQRSTVWXYZ")

(define-constant ERR_INVALID_ADDRESS (err u1000))
(define-constant ERR_INVALID_CONTRACT_NAME (err u1001))

(define-data-var addr-var (buff 400) 0x)

(define-public (address-string-to-principal (address (string-ascii 128)))
  (let (
    (period-index (index-of address "."))
  )
    (if (is-some period-index)
      (let (
        (address-part (unwrap-panic (slice? address u0 (unwrap-panic period-index))))
        (contract-name-part (unwrap-panic (slice? address u42 (len address))))
      )
        (begin
          (asserts! (is-eq (unwrap-panic period-index) u41) ERR_INVALID_ADDRESS)
          (asserts! (is-valid-c32 address-part) ERR_INVALID_ADDRESS)
          (ok (unwrap-panic (c32-decode address-part (as-max-len? contract-name-part u40))))
        )
      )
      (begin
        (asserts! (is-eq (len address) u41) ERR_INVALID_ADDRESS)
        (asserts! (is-valid-c32 address) ERR_INVALID_ADDRESS)
        (ok (unwrap-panic (c32-decode address none)))
      )
    )
  )
)

(define-private (c32-decode-aux (input (string-ascii 1)) (res {bit-buff: uint, bits-remaining: uint}))
  (let ((index (unwrap-panic (index-of? C32SET input)))
        (bit-buff (bit-or (bit-shift-left (get bit-buff res) u5) index))
        (bits-remaining (+ (get bits-remaining res) u5)))
    (if (>= bits-remaining u8)
        (let ((char (to-buff (bit-and (bit-shift-right bit-buff (- bits-remaining u8)) u255)))
              (bits-remaining1 (- bits-remaining u8))
              (bit-buff1 (bit-and bit-buff (- (bit-shift-left u1 bits-remaining1) u1))))
          (set (unwrap-panic (as-max-len? (var-get addr-var) u399)) char)
          (tuple (bit-buff bit-buff1) (bits-remaining bits-remaining1)))
        (tuple (bit-buff bit-buff) (bits-remaining bits-remaining)))))

(define-private (c32-decode (address (string-ascii 128)) (contract-name (optional (string-ascii 40))))
  (begin
    (var-set addr-var 0x)
    (fold c32-decode-aux (unwrap-panic (slice? address u1 (- (len address) u5))) (tuple (bit-buff u0) (bits-remaining u0)))
    (let ((version (to-buff (unwrap-panic (index-of? C32SET (unwrap-panic (element-at? address u1))))))
          (pub-key-hash (unwrap-panic (slice? (var-get addr-var) u1 u21))))
      (if (is-some contract-name)
        (principal-construct? version (unwrap-panic (as-max-len? pub-key-hash u20)) (unwrap-panic contract-name))
        (principal-construct? version (unwrap-panic (as-max-len? pub-key-hash u20)))
      )
    )
  )
)

(define-private (set (address (buff 399)) (char (buff 1)))
  (var-set addr-var (concat address char)))

(define-private (to-buff (data uint))
  (begin
    (let ((encoded (unwrap-panic (to-consensus-buff? data))))
      (unwrap-panic (element-at? encoded (- (len encoded) u1))))))


(define-private (is-valid-c32 (address (string-ascii 128)))
  (fold is-c32-char address true))

(define-private (is-c32-char (char (string-ascii 1)) (valid bool))
  (and valid (is-some (index-of C32SET char))))
