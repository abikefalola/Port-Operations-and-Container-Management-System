;; Port Operations Management Smart Contract
;; Handles vessel operations, port activities, and resource coordination

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-VESSEL-NOT-FOUND (err u201))
(define-constant ERR-VESSEL-EXISTS (err u202))
(define-constant ERR-INVALID-STATUS (err u203))
(define-constant ERR-INVALID-INPUT (err u204))
(define-constant ERR-PORT-NOT-FOUND (err u205))
(define-constant ERR-OPERATION-FAILED (err u206))
(define-constant ERR-CAPACITY-EXCEEDED (err u207))

;; Data Variables
(define-data-var next-operation-id uint u1)
(define-data-var port-operational-status (string-ascii 20) "operational")

;; Data Maps
(define-map vessels
  { vessel-id: (string-ascii 30) }
  {
    vessel-name: (string-ascii 50),
    vessel-type: (string-ascii 20),
    flag-state: (string-ascii 30),
    gross-tonnage: uint,
    length: uint,
    beam: uint,
    draft: uint,
    captain: (string-ascii 50),
    agent: principal,
    registered-at: uint
  }
)

(define-map vessel-arrivals
  { vessel-id: (string-ascii 30), arrival-id: uint }
  {
    arrival-time: uint,
    expected-departure: uint,
    actual-departure: (optional uint),
    port-of-origin: (string-ascii 50),
    next-destination: (string-ascii 50),
    cargo-manifest: (string-ascii 200),
    status: (string-ascii 20),
    berth-assigned: (optional (string-ascii 10)),
    processed-by: principal
  }
)

(define-map port-activities
  { activity-id: uint }
  {
    vessel-id: (string-ascii 30),
    activity-type: (string-ascii 30),
    start-time: uint,
    end-time: (optional uint),
    location: (string-ascii 50),
    description: (string-ascii 200),
    status: (string-ascii 20),
    operator: principal,
    containers-involved: uint
  }
)

(define-map port-resources
  { resource-id: (string-ascii 20) }
  {
    resource-type: (string-ascii 30),
    capacity: uint,
    current-usage: uint,
    status: (string-ascii 20),
    location: (string-ascii 50),
    hourly-rate: uint,
    operator: principal
  }
)

(define-map resource-allocations
  { allocation-id: uint }
  {
    resource-id: (string-ascii 20),
    vessel-id: (string-ascii 30),
    allocated-at: uint,
    duration: uint,
    purpose: (string-ascii 50),
    allocated-by: principal,
    status: (string-ascii 20)
  }
)

(define-map port-operators
  { operator: principal }
  { authorized: bool, role: (string-ascii 30), port-section: (string-ascii 20) }
)

;; Authorization Functions
(define-private (is-authorized (caller principal))
  (or
    (is-eq caller CONTRACT-OWNER)
    (default-to false (get authorized (map-get? port-operators { operator: caller })))
  )
)

(define-private (is-vessel-agent (vessel-id (string-ascii 30)) (caller principal))
  (match (map-get? vessels { vessel-id: vessel-id })
    vessel-data (is-eq caller (get agent vessel-data))
    false
  )
)

;; Validation Functions
(define-private (is-valid-vessel-status (status (string-ascii 20)))
  (or
    (is-eq status "approaching")
    (is-eq status "arrived")
    (is-eq status "berthed")
    (is-eq status "loading")
    (is-eq status "unloading")
    (is-eq status "departed")
    (is-eq status "anchored")
  )
)

(define-private (is-valid-activity-type (activity-type (string-ascii 30)))
  (or
    (is-eq activity-type "container-loading")
    (is-eq activity-type "container-unloading")
    (is-eq activity-type "fuel-bunkering")
    (is-eq activity-type "maintenance")
    (is-eq activity-type "customs-inspection")
    (is-eq activity-type "cargo-inspection")
    (is-eq activity-type "pilotage")
  )
)

(define-private (is-valid-resource-type (resource-type (string-ascii 30)))
  (or
    (is-eq resource-type "crane")
    (is-eq resource-type "tugboat")
    (is-eq resource-type "pilot")
    (is-eq resource-type "forklift")
    (is-eq resource-type "truck")
    (is-eq resource-type "warehouse-space")
  )
)

;; Vessel Management Functions
(define-public (register-vessel
  (vessel-id (string-ascii 30))
  (vessel-name (string-ascii 50))
  (vessel-type (string-ascii 20))
  (flag-state (string-ascii 30))
  (gross-tonnage uint)
  (length uint)
  (beam uint)
  (draft uint)
  (captain (string-ascii 50)))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (> (len vessel-id) u0) ERR-INVALID-INPUT)
    (asserts! (> (len vessel-name) u0) ERR-INVALID-INPUT)
    (asserts! (> gross-tonnage u0) ERR-INVALID-INPUT)
    (asserts! (> length u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? vessels { vessel-id: vessel-id })) ERR-VESSEL-EXISTS)

    (map-set vessels
      { vessel-id: vessel-id }
      {
        vessel-name: vessel-name,
        vessel-type: vessel-type,
        flag-state: flag-state,
        gross-tonnage: gross-tonnage,
        length: length,
        beam: beam,
        draft: draft,
        captain: captain,
        agent: tx-sender,
        registered-at: current-time
      }
    )

    (print {
      event: "vessel-registered",
      vessel-id: vessel-id,
      vessel-name: vessel-name,
      agent: tx-sender
    })

    (ok vessel-id)
  )
)

(define-public (register-vessel-arrival
  (vessel-id (string-ascii 30))
  (expected-departure uint)
  (port-of-origin (string-ascii 50))
  (next-destination (string-ascii 50))
  (cargo-manifest (string-ascii 200)))
  (let
    (
      (vessel-data (unwrap! (map-get? vessels { vessel-id: vessel-id }) ERR-VESSEL-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (arrival-id (var-get next-operation-id))
    )
    (asserts! (or (is-vessel-agent vessel-id tx-sender) (is-authorized tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> expected-departure current-time) ERR-INVALID-INPUT)
    (asserts! (> (len port-of-origin) u0) ERR-INVALID-INPUT)
    (asserts! (> (len next-destination) u0) ERR-INVALID-INPUT)

    (map-set vessel-arrivals
      { vessel-id: vessel-id, arrival-id: arrival-id }
      {
        arrival-time: current-time,
        expected-departure: expected-departure,
        actual-departure: none,
        port-of-origin: port-of-origin,
        next-destination: next-destination,
        cargo-manifest: cargo-manifest,
        status: "arrived",
        berth-assigned: none,
        processed-by: tx-sender
      }
    )

    (var-set next-operation-id (+ arrival-id u1))

    (print {
      event: "vessel-arrival-registered",
      vessel-id: vessel-id,
      arrival-id: arrival-id,
      arrival-time: current-time,
      port-of-origin: port-of-origin
    })

    (ok arrival-id)
  )
)

(define-public (register-vessel-departure
  (vessel-id (string-ascii 30))
  (arrival-id uint))
  (let
    (
      (arrival-data (unwrap! (map-get? vessel-arrivals { vessel-id: vessel-id, arrival-id: arrival-id }) ERR-VESSEL-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (or (is-vessel-agent vessel-id tx-sender) (is-authorized tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (get actual-departure arrival-data)) ERR-INVALID-INPUT)

    (map-set vessel-arrivals
      { vessel-id: vessel-id, arrival-id: arrival-id }
      (merge arrival-data {
        actual-departure: (some current-time),
        status: "departed"
      })
    )

    (print {
      event: "vessel-departure-registered",
      vessel-id: vessel-id,
      arrival-id: arrival-id,
      departure-time: current-time
    })

    (ok true)
  )
)

;; Port Activity Management
(define-public (create-port-activity
  (vessel-id (string-ascii 30))
  (activity-type (string-ascii 30))
  (location (string-ascii 50))
  (description (string-ascii 200))
  (containers-involved uint))
  (let
    (
      (activity-id (var-get next-operation-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-activity-type activity-type) ERR-INVALID-INPUT)
    (asserts! (> (len location) u0) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? vessels { vessel-id: vessel-id })) ERR-VESSEL-NOT-FOUND)

    (map-set port-activities
      { activity-id: activity-id }
      {
        vessel-id: vessel-id,
        activity-type: activity-type,
        start-time: current-time,
        end-time: none,
        location: location,
        description: description,
        status: "in-progress",
        operator: tx-sender,
        containers-involved: containers-involved
      }
    )

    (var-set next-operation-id (+ activity-id u1))

    (print {
      event: "port-activity-created",
      activity-id: activity-id,
      vessel-id: vessel-id,
      activity-type: activity-type,
      operator: tx-sender
    })

    (ok activity-id)
  )
)

(define-public (complete-port-activity (activity-id uint))
  (let
    (
      (activity-data (unwrap! (map-get? port-activities { activity-id: activity-id }) ERR-OPERATION-FAILED))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status activity-data) "in-progress") ERR-INVALID-STATUS)

    (map-set port-activities
      { activity-id: activity-id }
      (merge activity-data {
        end-time: (some current-time),
        status: "completed"
      })
    )

    (print {
      event: "port-activity-completed",
      activity-id: activity-id,
      completion-time: current-time
    })

    (ok true)
  )
)

;; Resource Management
(define-public (register-port-resource
  (resource-id (string-ascii 20))
  (resource-type (string-ascii 30))
  (capacity uint)
  (location (string-ascii 50))
  (hourly-rate uint))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len resource-id) u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-resource-type resource-type) ERR-INVALID-INPUT)
    (asserts! (> capacity u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? port-resources { resource-id: resource-id })) ERR-INVALID-INPUT)

    (map-set port-resources
      { resource-id: resource-id }
      {
        resource-type: resource-type,
        capacity: capacity,
        current-usage: u0,
        status: "available",
        location: location,
        hourly-rate: hourly-rate,
        operator: tx-sender
      }
    )

    (print {
      event: "port-resource-registered",
      resource-id: resource-id,
      resource-type: resource-type,
      capacity: capacity
    })

    (ok resource-id)
  )
)

(define-public (allocate-resource
  (resource-id (string-ascii 20))
  (vessel-id (string-ascii 30))
  (duration uint)
  (purpose (string-ascii 50)))
  (let
    (
      (resource-data (unwrap! (map-get? port-resources { resource-id: resource-id }) ERR-OPERATION-FAILED))
      (allocation-id (var-get next-operation-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-authorized tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status resource-data) "available") ERR-INVALID-STATUS)
    (asserts! (> duration u0) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? vessels { vessel-id: vessel-id })) ERR-VESSEL-NOT-FOUND)

    ;; Update resource status
    (map-set port-resources
      { resource-id: resource-id }
      (merge resource-data {
        status: "allocated",
        current-usage: (+ (get current-usage resource-data) u1)
      })
    )

    ;; Create allocation record
    (map-set resource-allocations
      { allocation-id: allocation-id }
      {
        resource-id: resource-id,
        vessel-id: vessel-id,
        allocated-at: current-time,
        duration: duration,
        purpose: purpose,
        allocated-by: tx-sender,
        status: "active"
      }
    )

    (var-set next-operation-id (+ allocation-id u1))

    (print {
      event: "resource-allocated",
      allocation-id: allocation-id,
      resource-id: resource-id,
      vessel-id: vessel-id,
      duration: duration
    })

    (ok allocation-id)
  )
)

;; Port Status Management
(define-public (update-port-status (new-status (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (or
      (is-eq new-status "operational")
      (is-eq new-status "restricted")
      (is-eq new-status "closed")
      (is-eq new-status "emergency")) ERR-INVALID-STATUS)

    (var-set port-operational-status new-status)

    (print {
      event: "port-status-updated",
      new-status: new-status,
      updated-by: tx-sender
    })

    (ok true)
  )
)

(define-public (authorize-port-operator
  (operator principal)
  (role (string-ascii 30))
  (port-section (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len role) u0) ERR-INVALID-INPUT)

    (map-set port-operators
      { operator: operator }
      { authorized: true, role: role, port-section: port-section }
    )

    (print {
      event: "port-operator-authorized",
      operator: operator,
      role: role,
      port-section: port-section
    })

    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-vessel-info (vessel-id (string-ascii 30)))
  (map-get? vessels { vessel-id: vessel-id })
)

(define-read-only (get-vessel-arrival (vessel-id (string-ascii 30)) (arrival-id uint))
  (map-get? vessel-arrivals { vessel-id: vessel-id, arrival-id: arrival-id })
)

(define-read-only (get-port-activity (activity-id uint))
  (map-get? port-activities { activity-id: activity-id })
)

(define-read-only (get-port-resource (resource-id (string-ascii 20)))
  (map-get? port-resources { resource-id: resource-id })
)

(define-read-only (get-resource-allocation (allocation-id uint))
  (map-get? resource-allocations { allocation-id: allocation-id })
)

(define-read-only (get-port-status)
  (var-get port-operational-status)
)

(define-read-only (is-port-operator-authorized (operator principal))
  (default-to false (get authorized (map-get? port-operators { operator: operator })))
)

(define-read-only (get-operator-role (operator principal))
  (get role (map-get? port-operators { operator: operator }))
)

;; Utility Functions
(define-read-only (get-current-port-capacity)
  ;; Simplified capacity calculation
  (ok u1000) ;; Placeholder - would calculate based on available resources
)

(define-read-only (get-vessels-in-port)
  ;; Note: This would require iteration in a real implementation
  (ok "Use off-chain indexing for complex queries")
)
