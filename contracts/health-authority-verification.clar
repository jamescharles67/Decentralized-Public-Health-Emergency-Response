;; Health Authority Verification Contract
;; Manages verification and registration of health response agencies

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_VERIFIED (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_AUTHORITY (err u103))

;; Authority levels
(define-constant AUTHORITY_FEDERAL u1)
(define-constant AUTHORITY_STATE u2)
(define-constant AUTHORITY_LOCAL u3)
(define-constant AUTHORITY_NGO u4)

;; Data structures
(define-map verified-authorities
  principal
  {
    name: (string-ascii 100),
    authority-level: uint,
    verified-at: uint,
    verified-by: principal,
    active: bool
  }
)

(define-map authority-permissions
  principal
  {
    can-verify-others: bool,
    can-declare-emergency: bool,
    can-allocate-resources: bool
  }
)

;; Read-only functions
(define-read-only (is-verified-authority (authority principal))
  (match (map-get? verified-authorities authority)
    authority-data (get active authority-data)
    false
  )
)

(define-read-only (get-authority-info (authority principal))
  (map-get? verified-authorities authority)
)

(define-read-only (get-authority-permissions (authority principal))
  (map-get? authority-permissions authority)
)

(define-read-only (can-verify-others (authority principal))
  (match (map-get? authority-permissions authority)
    perms (get can-verify-others perms)
    false
  )
)

;; Public functions
(define-public (verify-authority
  (authority principal)
  (name (string-ascii 100))
  (authority-level uint)
)
  (begin
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (can-verify-others tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? verified-authorities authority)) ERR_ALREADY_VERIFIED)
    (asserts! (<= authority-level AUTHORITY_NGO) ERR_INVALID_AUTHORITY)

    (map-set verified-authorities authority {
      name: name,
      authority-level: authority-level,
      verified-at: block-height,
      verified-by: tx-sender,
      active: true
    })

    ;; Set default permissions based on authority level
    (map-set authority-permissions authority {
      can-verify-others: (<= authority-level AUTHORITY_STATE),
      can-declare-emergency: (<= authority-level AUTHORITY_LOCAL),
      can-allocate-resources: (<= authority-level AUTHORITY_LOCAL)
    })

    (ok true)
  )
)

(define-public (revoke-authority (authority principal))
  (begin
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (can-verify-others tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? verified-authorities authority)) ERR_NOT_FOUND)

    (map-set verified-authorities authority
      (merge (unwrap-panic (map-get? verified-authorities authority)) {active: false})
    )

    (ok true)
  )
)

(define-public (update-permissions
  (authority principal)
  (can-verify bool)
  (can-declare bool)
  (can-allocate bool)
)
  (begin
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (can-verify-others tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-verified-authority authority) ERR_NOT_FOUND)

    (map-set authority-permissions authority {
      can-verify-others: can-verify,
      can-declare-emergency: can-declare,
      can-allocate-resources: can-allocate
    })

    (ok true)
  )
)
