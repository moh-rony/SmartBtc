;; title: SmartBtc
;; version: 1.0.0
;; summary: A critical AMM pool that brings smart contract functionality to synthetic Bitcoin
;; description: This contract implements an automated market maker (AMM) pool for synthetic Bitcoin,
;;              unlocking generalized DeFi primitives on Stacks with constant product formula (x * y = k)

;; traits
;;

;; token definitions
;; SIP-010 compliant fungible token for LP tokens
(define-fungible-token smartbtc-lp-token)

;; constants
;;
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-insufficient-liquidity (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-slippage-too-high (err u105))
(define-constant err-pool-empty (err u106))
(define-constant err-already-initialized (err u107))
(define-constant err-not-initialized (err u108))
(define-constant err-invalid-pair (err u109))
(define-constant err-zero-amount (err u110))

;; Minimum liquidity locked forever to prevent division by zero
(define-constant minimum-liquidity u1000)

;; Fee configuration (0.3% = 30 basis points)
(define-constant fee-basis-points u30)
(define-constant fee-denominator u10000)

;; data vars
;;
(define-data-var pool-initialized bool false)
(define-data-var reserve-stx uint u0)
(define-data-var reserve-sbtc uint u0)
(define-data-var total-lp-supply uint u0)
(define-data-var protocol-fee-stx uint u0)
(define-data-var protocol-fee-sbtc uint u0)

;; data maps
;;
(define-map liquidity-providers principal uint)
(define-map user-balances-stx principal uint)
(define-map user-balances-sbtc principal uint)

;; public functions
;;

;; Initialize the pool with initial liquidity
(define-public (initialize-pool (initial-stx uint) (initial-sbtc uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (var-get pool-initialized) false) err-already-initialized)
        (asserts! (> initial-stx u0) err-zero-amount)
        (asserts! (> initial-sbtc u0) err-zero-amount)

        ;; Calculate initial LP tokens (geometric mean)
        (let (
            (initial-liquidity (sqrt-uint (* initial-stx initial-sbtc)))
        )
            (asserts! (>= initial-liquidity minimum-liquidity) err-insufficient-liquidity)

            ;; Lock minimum liquidity forever
            (try! (ft-mint? smartbtc-lp-token minimum-liquidity (as-contract tx-sender)))

            ;; Mint LP tokens to provider
            (let ((lp-amount (- initial-liquidity minimum-liquidity)))
                (try! (ft-mint? smartbtc-lp-token lp-amount tx-sender))
                (map-set liquidity-providers tx-sender lp-amount)

                ;; Update pool state
                (var-set reserve-stx initial-stx)
                (var-set reserve-sbtc initial-sbtc)
                (var-set total-lp-supply initial-liquidity)
                (var-set pool-initialized true)

                (ok {lp-tokens: lp-amount, stx-deposited: initial-stx, sbtc-deposited: initial-sbtc})
            )
        )
    )
)

;; Deposit STX to user's balance
(define-public (deposit-stx (amount uint))
    (begin
        (asserts! (> amount u0) err-zero-amount)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set user-balances-stx tx-sender
            (+ (default-to u0 (map-get? user-balances-stx tx-sender)) amount))
        (ok amount)
    )
)

;; Deposit synthetic BTC to user's balance
(define-public (deposit-sbtc (amount uint))
    (begin
        (asserts! (> amount u0) err-zero-amount)
        (map-set user-balances-sbtc tx-sender
            (+ (default-to u0 (map-get? user-balances-sbtc tx-sender)) amount))
        (ok amount)
    )
)

;; Withdraw STX from user's balance
(define-public (withdraw-stx (amount uint))
    (let (
        (user-balance (default-to u0 (map-get? user-balances-stx tx-sender)))
        (recipient tx-sender)
    )
        (asserts! (>= user-balance amount) err-insufficient-balance)
        (try! (as-contract (stx-transfer? amount tx-sender recipient)))
        (map-set user-balances-stx recipient (- user-balance amount))
        (ok amount)
    )
)

;; Withdraw synthetic BTC from user's balance
(define-public (withdraw-sbtc (amount uint))
    (let ((user-balance (default-to u0 (map-get? user-balances-sbtc tx-sender))))
        (asserts! (>= user-balance amount) err-insufficient-balance)
        (map-set user-balances-sbtc tx-sender (- user-balance amount))
        (ok amount)
    )
)

;; Add liquidity to the pool
(define-public (add-liquidity (stx-amount uint) (sbtc-amount uint) (min-lp-tokens uint))
    (begin
        (asserts! (var-get pool-initialized) err-not-initialized)
        (asserts! (> stx-amount u0) err-zero-amount)
        (asserts! (> sbtc-amount u0) err-zero-amount)

        (let (
            (reserve-x (var-get reserve-stx))
            (reserve-y (var-get reserve-sbtc))
            (total-supply (var-get total-lp-supply))
            (user-stx-balance (default-to u0 (map-get? user-balances-stx tx-sender)))
            (user-sbtc-balance (default-to u0 (map-get? user-balances-sbtc tx-sender)))
        )
            (asserts! (>= user-stx-balance stx-amount) err-insufficient-balance)
            (asserts! (>= user-sbtc-balance sbtc-amount) err-insufficient-balance)

            ;; Calculate LP tokens to mint
            (let (
                (lp-tokens (if (is-eq total-supply u0)
                    (sqrt-uint (* stx-amount sbtc-amount))
                    (min
                        (/ (* stx-amount total-supply) reserve-x)
                        (/ (* sbtc-amount total-supply) reserve-y)
                    )
                ))
            )
                (asserts! (>= lp-tokens min-lp-tokens) err-slippage-too-high)
                (asserts! (> lp-tokens u0) err-insufficient-liquidity)

                ;; Update user balances
                (map-set user-balances-stx tx-sender (- user-stx-balance stx-amount))
                (map-set user-balances-sbtc tx-sender (- user-sbtc-balance sbtc-amount))

                ;; Update reserves
                (var-set reserve-stx (+ reserve-x stx-amount))
                (var-set reserve-sbtc (+ reserve-y sbtc-amount))
                (var-set total-lp-supply (+ total-supply lp-tokens))

                ;; Mint LP tokens
                (try! (ft-mint? smartbtc-lp-token lp-tokens tx-sender))
                (map-set liquidity-providers tx-sender
                    (+ (default-to u0 (map-get? liquidity-providers tx-sender)) lp-tokens))

                (ok {lp-tokens: lp-tokens, stx-amount: stx-amount, sbtc-amount: sbtc-amount})
            )
        )
    )
)

;; Remove liquidity from the pool
(define-public (remove-liquidity (lp-tokens uint) (min-stx uint) (min-sbtc uint))
    (begin
        (asserts! (var-get pool-initialized) err-not-initialized)
        (asserts! (> lp-tokens u0) err-zero-amount)

        (let (
            (reserve-x (var-get reserve-stx))
            (reserve-y (var-get reserve-sbtc))
            (total-supply (var-get total-lp-supply))
            (user-lp-balance (default-to u0 (map-get? liquidity-providers tx-sender)))
        )
            (asserts! (>= user-lp-balance lp-tokens) err-insufficient-balance)
            (asserts! (> total-supply u0) err-pool-empty)

            ;; Calculate amounts to return
            (let (
                (stx-amount (/ (* lp-tokens reserve-x) total-supply))
                (sbtc-amount (/ (* lp-tokens reserve-y) total-supply))
            )
                (asserts! (>= stx-amount min-stx) err-slippage-too-high)
                (asserts! (>= sbtc-amount min-sbtc) err-slippage-too-high)
                (asserts! (> stx-amount u0) err-insufficient-liquidity)
                (asserts! (> sbtc-amount u0) err-insufficient-liquidity)

                ;; Burn LP tokens
                (try! (ft-burn? smartbtc-lp-token lp-tokens tx-sender))
                (map-set liquidity-providers tx-sender (- user-lp-balance lp-tokens))

                ;; Update reserves
                (var-set reserve-stx (- reserve-x stx-amount))
                (var-set reserve-sbtc (- reserve-y sbtc-amount))
                (var-set total-lp-supply (- total-supply lp-tokens))

                ;; Return tokens to user balance
                (map-set user-balances-stx tx-sender
                    (+ (default-to u0 (map-get? user-balances-stx tx-sender)) stx-amount))
                (map-set user-balances-sbtc tx-sender
                    (+ (default-to u0 (map-get? user-balances-sbtc tx-sender)) sbtc-amount))

                (ok {stx-amount: stx-amount, sbtc-amount: sbtc-amount, lp-tokens: lp-tokens})
            )
        )
    )
)

;; Swap STX for synthetic BTC
(define-public (swap-stx-for-sbtc (stx-in uint) (min-sbtc-out uint))
    (begin
        (asserts! (var-get pool-initialized) err-not-initialized)
        (asserts! (> stx-in u0) err-zero-amount)

        (let (
            (reserve-x (var-get reserve-stx))
            (reserve-y (var-get reserve-sbtc))
            (user-stx-balance (default-to u0 (map-get? user-balances-stx tx-sender)))
        )
            (asserts! (>= user-stx-balance stx-in) err-insufficient-balance)
            (asserts! (> reserve-y u0) err-pool-empty)

            ;; Calculate output with fee
            (let (
                (stx-in-with-fee (- stx-in (/ (* stx-in fee-basis-points) fee-denominator)))
                (sbtc-out (/ (* stx-in-with-fee reserve-y) (+ reserve-x stx-in-with-fee)))
            )
                (asserts! (>= sbtc-out min-sbtc-out) err-slippage-too-high)
                (asserts! (> sbtc-out u0) err-insufficient-liquidity)
                (asserts! (<= sbtc-out reserve-y) err-insufficient-liquidity)

                ;; Update user balances
                (map-set user-balances-stx tx-sender (- user-stx-balance stx-in))
                (map-set user-balances-sbtc tx-sender
                    (+ (default-to u0 (map-get? user-balances-sbtc tx-sender)) sbtc-out))

                ;; Update reserves
                (var-set reserve-stx (+ reserve-x stx-in))
                (var-set reserve-sbtc (- reserve-y sbtc-out))

                ;; Update protocol fees
                (var-set protocol-fee-stx
                    (+ (var-get protocol-fee-stx) (/ (* stx-in fee-basis-points) fee-denominator)))

                (ok {stx-in: stx-in, sbtc-out: sbtc-out})
            )
        )
    )
)

;; Swap synthetic BTC for STX
(define-public (swap-sbtc-for-stx (sbtc-in uint) (min-stx-out uint))
    (begin
        (asserts! (var-get pool-initialized) err-not-initialized)
        (asserts! (> sbtc-in u0) err-zero-amount)

        (let (
            (reserve-x (var-get reserve-stx))
            (reserve-y (var-get reserve-sbtc))
            (user-sbtc-balance (default-to u0 (map-get? user-balances-sbtc tx-sender)))
        )
            (asserts! (>= user-sbtc-balance sbtc-in) err-insufficient-balance)
            (asserts! (> reserve-x u0) err-pool-empty)

            ;; Calculate output with fee
            (let (
                (sbtc-in-with-fee (- sbtc-in (/ (* sbtc-in fee-basis-points) fee-denominator)))
                (stx-out (/ (* sbtc-in-with-fee reserve-x) (+ reserve-y sbtc-in-with-fee)))
            )
                (asserts! (>= stx-out min-stx-out) err-slippage-too-high)
                (asserts! (> stx-out u0) err-insufficient-liquidity)
                (asserts! (<= stx-out reserve-x) err-insufficient-liquidity)

                ;; Update user balances
                (map-set user-balances-sbtc tx-sender (- user-sbtc-balance sbtc-in))
                (map-set user-balances-stx tx-sender
                    (+ (default-to u0 (map-get? user-balances-stx tx-sender)) stx-out))

                ;; Update reserves
                (var-set reserve-sbtc (+ reserve-y sbtc-in))
                (var-set reserve-stx (- reserve-x stx-out))

                ;; Update protocol fees
                (var-set protocol-fee-sbtc
                    (+ (var-get protocol-fee-sbtc) (/ (* sbtc-in fee-basis-points) fee-denominator)))

                (ok {sbtc-in: sbtc-in, stx-out: stx-out})
            )
        )
    )
)

;; read only functions
;;

;; Get pool reserves
(define-read-only (get-reserves)
    {
        stx-reserve: (var-get reserve-stx),
        sbtc-reserve: (var-get reserve-sbtc),
        total-lp-supply: (var-get total-lp-supply)
    }
)

;; Get user's LP token balance
(define-read-only (get-lp-balance (user principal))
    (ok (default-to u0 (map-get? liquidity-providers user)))
)

;; Get user's STX balance
(define-read-only (get-user-stx-balance (user principal))
    (ok (default-to u0 (map-get? user-balances-stx user)))
)

;; Get user's synthetic BTC balance
(define-read-only (get-user-sbtc-balance (user principal))
    (ok (default-to u0 (map-get? user-balances-sbtc user)))
)

;; Calculate output amount for STX to sBTC swap
(define-read-only (get-stx-to-sbtc-quote (stx-in uint))
    (let (
        (reserve-x (var-get reserve-stx))
        (reserve-y (var-get reserve-sbtc))
    )
        (if (or (is-eq stx-in u0) (is-eq reserve-y u0))
            (ok u0)
            (let (
                (stx-in-with-fee (- stx-in (/ (* stx-in fee-basis-points) fee-denominator)))
                (sbtc-out (/ (* stx-in-with-fee reserve-y) (+ reserve-x stx-in-with-fee)))
            )
                (ok sbtc-out)
            )
        )
    )
)

;; Calculate output amount for sBTC to STX swap
(define-read-only (get-sbtc-to-stx-quote (sbtc-in uint))
    (let (
        (reserve-x (var-get reserve-stx))
        (reserve-y (var-get reserve-sbtc))
    )
        (if (or (is-eq sbtc-in u0) (is-eq reserve-x u0))
            (ok u0)
            (let (
                (sbtc-in-with-fee (- sbtc-in (/ (* sbtc-in fee-basis-points) fee-denominator)))
                (stx-out (/ (* sbtc-in-with-fee reserve-x) (+ reserve-y sbtc-in-with-fee)))
            )
                (ok stx-out)
            )
        )
    )
)

;; Get pool initialization status
(define-read-only (is-pool-initialized)
    (ok (var-get pool-initialized))
)

;; Get protocol fees collected
(define-read-only (get-protocol-fees)
    {
        stx-fees: (var-get protocol-fee-stx),
        sbtc-fees: (var-get protocol-fee-sbtc)
    }
)

;; Get current price (STX per sBTC)
(define-read-only (get-price)
    (let (
        (reserve-x (var-get reserve-stx))
        (reserve-y (var-get reserve-sbtc))
    )
        (if (is-eq reserve-y u0)
            (ok u0)
            (ok (/ (* reserve-x u1000000) reserve-y))
        )
    )
)

;; private functions
;;

;; Calculate square root using Newton's method (simplified)
;; Returns the integer square root of n
(define-private (sqrt-uint (n uint))
    (if (<= n u1)
        n
        (let ((initial-guess (/ n u2)))
            (get result (fold sqrt-iteration
                (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20)
                {n: n, guess: initial-guess, result: initial-guess}
            ))
        )
    )
)

(define-private (sqrt-iteration (iteration uint) (state {n: uint, guess: uint, result: uint}))
    (let (
        (n (get n state))
        (guess (get guess state))
        (new-guess (/ (+ guess (/ n guess)) u2))
    )
        {n: n, guess: new-guess, result: new-guess}
    )
)

;; Helper to get minimum of two numbers
(define-private (min (a uint) (b uint))
    (if (< a b) a b)
)