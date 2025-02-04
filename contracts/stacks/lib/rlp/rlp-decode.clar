(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_INVALID_RLP (err u401))
(define-constant ERR_INVALID_LENGTH (err u402))
(define-constant MAX_SIZE 512)

(define-read-only (get-item (input (list 2 (buff 2048))))
  (unwrap-panic (element-at? input u0))
)

(define-read-only (get-rlp (input (list 2 (buff 2048))))
  (unwrap-panic (element-at? input u1))
)

(define-read-only (rlp-decode-string (rlp (list 500 (buff 2048))) (index uint))
  (let (
     (data (unwrap-panic (element-at? rlp index))))
  (decode-string data)
  )
)

(define-read-only (decode-string (input (buff 2048)))
  (let (
        (length (unwrap-panic  (to-consensus-buff? (len input))))
        (sliced (unwrap-panic  (slice? length u13  (len length))))
        (data (concat sliced input))
        (res (concat 0x0d data))
    )
    (from-consensus-buff? (string-ascii 2048) res)
  )
)

(define-read-only (rlp-decode-uint (rlp (list 500 (buff 2048))) (index uint))
  (let (
     (data (unwrap-panic (element-at? rlp index))))
  
  (decode-uint data)
  )
)

(define-read-only (decode-uint (input (buff 2048)))
    (buff-to-uint-be (unwrap-panic (as-max-len? input u16)))
)

(define-read-only (rlp-decode-buff (rlp (list 500 (buff 2048))) (index uint))
  (let (
     (data (unwrap-panic (element-at? rlp index)))
     (decoded (decode-item data))
  )
  
  (unwrap-panic (element-at? decoded u0))
  )
)

(define-private (get-long-item (id uint) (index uint) (input (buff 2048)))
  (let (
    (length-bytes-count (- index id))
    (length-bytes (unwrap-panic (slice? input u1 (+ u1 length-bytes-count))))
    (item-length (buff-to-uint-be (unwrap-panic (as-max-len? length-bytes u16))))
    )
    (list (default-to 0x (slice? input (+ u1 length-bytes-count) (+ u1 length-bytes-count item-length))) 
          (default-to 0x (slice? input (+ u1 length-bytes-count item-length) (len input)))
    )
  )
)

(define-private (get-short-item (id uint) (index uint) (input (buff 2048)))
  (let ((item-length (- index id)))
    (list 
      (default-to 0x (slice? input u1 (+ u1 item-length)))
      (default-to 0x (slice? input (+ u1 item-length) (len input)))
    )
  )
)

(define-read-only (decode-item (input (buff 2048)))
  (let (
      (first-byte (unwrap-panic (element-at? input u0)))
      (length (buff-to-uint-be first-byte))
      )
    (if (< length u128)
      ;; Check if this is a string (first byte between 0x80 and 0xb7)
      (if (and (>= length u128) (< length u184))
        ;; For strings, keep the length prefix
        (list 
          input
          (default-to 0x (slice? input u1 (len input)))
        )
        ;; For other types, strip the length prefix
        (list 
          (default-to 0x (slice? input u0 u1)) 
          (default-to 0x (slice? input u1 (len input)))
        ))
    (if (< length u184)
      (get-short-item u128 length input)
    (if (< length u192)
      (get-long-item  u183 length input)
    (if (< length u248)
      (get-short-item u192 length input)
      (get-long-item  u247 length input)
    ))))
  )
)

(define-read-only (rlp-decode-list (rlp (list 500 (buff 2048))) (index uint))
  (let (
     (data (unwrap-panic (element-at? rlp index))))
  
  (to-list data)
  )
)

(define-read-only (rlp-to-list (input (buff 2048)))
  (let (
      (item (decode-item  input))
      (lst (get-item item))
    )
  (to-list lst)
  )
)

(define-read-only (to-list (input (buff 2048)))
    (if (is-eq input 0x)
    (list )
    (let (
      (d1 (decode-item  input))
      (i1 (get-item  d1))
      (d2_ (get-rlp  d1))
    )
    (if (is-eq  d2_ 0x)
      (list i1)
      (let (
        (d2 (decode-item  d2_))
        (i2 (get-item  d2))
        (d3_ (get-rlp  d2))
      )
      (if (is-eq  d3_ 0x)
        (list i1 i2)
        (let (
          (d3 (decode-item  d3_))
          (i3 (get-item  d3))
          (d4_ (get-rlp  d3))
        )
        (if (is-eq  d4_ 0x)
          (list i1 i2 i3)
          (let (
            (d4 (decode-item  d4_))
            (i4 (get-item  d4))
            (d5_ (get-rlp  d4))
          )
          (if (is-eq  d5_ 0x)
            (list i1 i2 i3 i4)
            (let (
              (d5 (decode-item  d5_))
              (i5 (get-item  d5))
              (d6_ (get-rlp  d5))
            )
            (if (is-eq  d6_ 0x)
              (list i1 i2 i3 i4 i5)
              (let (
                (d6 (decode-item  d6_))
                (i6 (get-item  d6))
                (d7_ (get-rlp  d6))
              )
              (if (is-eq  d7_ 0x)
                (list i1 i2 i3 i4 i5 i6)
                (let (
                  (d7 (decode-item  d7_))
                  (i7 (get-item  d7))
                  (d8_ (get-rlp  d7))
                )
                (if (is-eq  d8_ 0x)
                  (list i1 i2 i3 i4 i5 i6 i7)
                  (let (
                    (d8 (decode-item  d8_))
                    (i8 (get-item  d8))
                    (d9_ (get-rlp  d8))
                  )
                  (if (is-eq  d8_ 0x)
                    (list i1 i2 i3 i4 i5 i6 i7 i8)
                    (let (
                      (d9 (decode-item  d8_))
                      (i9 (get-item  d8))
                    )
                    (list i1 i2 i3 i4 i5 i6 i7 i8 i9)
                    ))
                  ))
                ))
              ))
            ))
          ))
        ))
      ))
    ))
)