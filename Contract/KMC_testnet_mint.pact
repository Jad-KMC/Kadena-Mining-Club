
(namespace "free")
;; For more information about keysets checkout:
;; https://pact-language.readthedocs.io/en/latest/pact-reference.html#keysets-and-authorization
(define-keyset 'KMC-testnet-mint-1212 (read-keyset "KMC-testnet-mint-1212"))


(module KMC_testnet_mint 'KMC-testnet-mint-1212
  @doc "Kadena Mining Club testnet mint contract."
    (use coin)

; ============================================
; ==               CONSTANTS                ==
; ============================================

    (defconst ADMIN_KEYSET (read-keyset 'KMC-testnet-mint-1212))
    (defconst ACCOUNTS_CREATED_COUNT "accounts created")
    (defconst MINERS_CREATED_COUNT "miners-count")

    (defconst WL_KD2_ROLE "wl-kd2-role") ; lets user mint 1 NFT at discounted price
    (defconst WL_KD5_ROLE "wl-kd5-role") ; lets user mint 2 NFTs at discounted price
    (defconst WL_KD6_ROLE "wl-kd6-role") ; lets user mint 3 NFTs at discounted price
    (defconst WL_KD7_ROLE "wl-kd7-role") ; lets user mint 5 NFTs at discounted price
    (defconst WL_KD8_ROLE "wl-kd8-role") ; lets user mint 10 NFT at discounted price

    (defconst PRICE_KEY "price-key")
    (defconst MINERS_URI_KEY "miners-uri-key")
    (defconst ADMIN_ADDRESS "k:ab7cef70e1d91a138b8f65d26d6917ffcb852b84525b7dc2193843e8dfebf799")
    (defconst MAX_SUPPLY 10000 "The max supply of generation 0 miners")
    (defconst MINT_WALLET "k:aaf2c6d193b5e8cf73d78d533e3e6a55f08eb518b481996bbf4c4e55cdcadaf0") ;;placeholder for payments contract

    (defconst MINIMUM_PRECISION 0
      "Specifies the minimum denomination for token transactions.")
    (defconst uACCOUNT_ID_CHARSET CHARSET_LATIN1
      "Allowed character set for Account IDs.")
    (defconst uACCOUNT_ID_MIN_LENGTH 3
      "Minimum character length for account IDs.")
    (defconst uACCOUNT_ID_MAX_LENGTH 256
      "Maximum character length for account IDs.")

; ============================================
; ==             CAPABILITIES               ==
; ============================================

    (defcap ADMIN() ; Used for admin functions
        @doc "Only allows admin to call these"
        (enforce-keyset ADMIN_KEYSET)
        (compose-capability (PRIVATE))
        (compose-capability (ACCOUNT_GUARD ADMIN_ADDRESS))
    )

    (defcap ACCOUNT_GUARD (account:string)
        @doc "Verifies account meets format and belongs to caller"
        (enforce (= "k:" (take 2 account)) "For security, only support k: accounts")
        (enforce-guard
            (at "guard" (coin.details account))
        )
    )

    (defcap GOVERNANCE()
        @doc "Only allows admin to call these"
        (enforce-keyset ADMIN_KEYSET)
    )

    (defcap OWNER (account:string id:string)
        @doc "Enforces that an account owns the particular miner ID"
        (let
            (
                (nft-owner (at "owner-address" (read mledger id ["owner-address"])))
            )
            (enforce (= nft-owner account) "Account is not owner of the NFT")
                (compose-capability (ACCOUNT_GUARD account))
        )
    )

    (defcap INTERNAL ()
        @doc "For Internal Use"
        true
    )

    (defcap KMCNFT_BUY_NFT (id:string account:string)
        @doc "Emitted event when an NFT is purchased"
        @event true
    )


    ; (defcap TRANSFER:bool (id:string sender:string receiver:string amount:decimal)
    ;     @doc "Allows transferring of NFTs"

    ; )

    (defcap PRIVATE ()
        true
    )

; ============================================
; ==            SCHEMA AND TABLES           ==
; ============================================

    (defschema wl-schema
        @doc "Basic schema used for WL members, keys are account ids"
        role:string
    )

    (defschema counts-schema
        ; a schema to keep track of how many things there are
        count:integer
    )

    (defschema price-schema
        price:decimal
    )

    ; every entry is one transaction, to be stored on the ledger "mledger"
    (defschema entry
        nft-id:string
        generation:integer
        owner-address:string
        uri:string
        hashrate-multiplier:decimal
        tied-asic:string
    )

    (deftable wl:{wl-schema})
    (deftable mledger:{entry})
    (deftable counts-table:{counts-schema})
    (deftable price-table:{price-schema})

    (defun initialize ()
        @doc "Initialize the module the first time it is deployed"
        (insert counts-table ACCOUNTS_CREATED_COUNT {"count": 0})
        (insert counts-table MINERS_CREATED_COUNT {"count": 0})
        (insert price-table PRICE_KEY {"price": 0.001})
    )

; ============================================
; ==           COIN ACCOUNT CHECKS          ==
; ============================================
    (defun enforce-coin-account-exists (account:string)
        (let ((exist (coin-account-exists account)))
            (enforce exist "Account does not exist in coin contract"))
    )

    (defun coin-account-exists:bool (account:string)
        (try false
            (let ((ok true))
                (coin.details account)
                ok))
    )

    (defun coin-account-guard (account:string)
        @doc "enforces coin account guard"
        (at "guard" (coin.details account))
    )

    (defun get-coin-guard (account)
       (format "{}" [(at "guard" (coin.details account))])
    )

    (defun key (id:string account:string)
        @doc "returns id/account data structure"
        (format "{}:{}" [id account])
    )

    ;Enforces rules for account IDs
    (defun validate-account-id ( accountId:string )
        @doc " Enforce that an account ID meets charset and length requirements. "
        (enforce
            (is-charset uACCOUNT_ID_CHARSET accountId)
            (format
            "Account ID does not conform to the required charset: {}"
            [accountId]))
        (let ((accountLength (length accountId)))
            (enforce
                (>= accountLength uACCOUNT_ID_MIN_LENGTH)
                (format
                    "Account ID does not conform to the min length requirement: {}"
                    [accountId]))
            (enforce
                (<= accountLength uACCOUNT_ID_MAX_LENGTH)
                (format
                    "Account ID does not conform to the max length requirement: {}"
                    [accountId])))
  )

    ;Enforces valid amounts of token
    (defun enforce-valid-amount
        ( precision:integer
          amount:decimal)
        @doc " Enforces positive amounts "
        (enforce (> amount 0.0) "Positive non-zero amounts only.")
        (enforce-precision precision amount)
    )

    ;Enforces token precision of decimal placement
    (defun enforce-precision
        ( precision:integer
          amount:decimal)
        @doc " Enforces whole numbers "
        (enforce
            (= (floor amount precision) amount)
            "Whole NFTs only.")
    )

; ============================================
; ==       State-modifying functions        ==
; ============================================

    ; (defun create-account (account:string)
    ;     @doc "Creates an account"

    ;     (enforce-coin-account-exists account)
    ;     (with-capability (ACCOUNT_GUARD account)
    ;         (let ((id (id-for-new-account)))
    ;             (insert mledger (key id account)
    ;                 { "nfts-held" : 0
    ;                 , "guard"   : (coin-account-guard account)
    ;                 , "id"      : id
    ;                 , "account" : account
    ;                 }
    ;             )
                ; (with-capability (PRIVATE) (increase-count ACCOUNTS_CREATED_COUNT)))
    ;     )
    ; )

    (defun increase-count (key:string)
        ;increase the count of a key in a table by 1
        (require-capability (PRIVATE))
        (update counts-table key {"count": (+ 1 (get-count key))})
    )

    (defun add-to-wl-for-role (role:string accounts:list )
        @doc "Adds wl users with a role"
        (enforce
            (
                or?
                (= WL_KD2_ROLE)
                (= WL_KD5_ROLE)
                (= WL_KD6_ROLE)
                (= WL_KD7_ROLE)
                (= WL_KD8_ROLE)
                role
            )
            "Must specify a valid role for adding WL members"
        )
        (with-capability (ADMIN)
            (map (add-to-wl role) accounts)
        )
    )

    (defun add-to-wl (role:string account:string )
        @doc "Adds a user to a wl"
        (require-capability (ADMIN))
        (insert wl account {"role": role})
    )

    (defun set-asic (nft-id:integer asic-num:string)
        (update mledger nft-id {"tied-asic": asic-num})
    )

    ; (defun fake-mint (account:string amount:integer)
    ;     @doc "This simply sends KDA from one account to the Admin_address, test function only"
    ;     (with-capability (ACCOUNT_GUARD account)
    ;         (coin.transfer account ADMIN_ADDRESS (* 0.1 amount))
    ;     )
    ; )

    (defun mint-nft ( account:string amount:decimal) ;add guard:guard
        @doc "Mint an NFT"
        (with-default-read counts-table MINERS_CREATED_COUNT
          { 'count: 0.0 }
          { 'count := current-count }

          (enforce (> MAX_SUPPLY current-count ) (format "current-supply is {}" [current-count]))
        )
        (with-default-read price-table PRICE_KEY
          { 'price: 0.0 }
          { 'price := price_1 }
          (enforce (= amount price_1) "price is incorrect")
        )
        (validate-account-id account)
        (enforce (= "k:" (take 2 account)) "Only k: prefixed accounts for security purposes") ; not necessary with ACCOUNT_GUARD
        (enforce-coin-account-exists account)
        ;; (let ((cur_guard (coin-account-guard account)))
        ;;     (enforce (= cur_guard guard) "KMC Account guards must match coin account guards")
        ;; )
        (coin.transfer account ADMIN_ADDRESS amount)
        (write mledger (key (id-for-new-nft) account) ;this looks like "1:k:a7...x8"
            { "nft-id"        : (id-for-new-nft)
            , "generation"    : 1
            , "owner-address" : account
            , "uri"           : "PLACEHOLDER" ;implement function to read from IPFS/JSON table
            , "hashrate-multiplier" : 1.0
            , "tied-asic"     : "null" }) ;this will be null for all NFTs until ASIC delivery, must be updated by admin
        (with-capability (PRIVATE) (increase-count MINERS_CREATED_COUNT))
        (format "1 NFT purchased for {} KDA." [amount])
    )

; ============================================
; ==     NON STATE-MODIFYING FUNCTIONS      ==
; ============================================

    (defun get-uri:string (nft-id:string)
        @doc "Returns the uri of an NFT"
        (at "uri" (read mledger nft-id ['uri] ))
    )

    (defun get-price ()
        ; gets the price for a key
        (at "price" (read price-table PRICE_KEY ["price"]))
    )

    (defun get-count (key:string)
        ;gets the count for a key
        (at "count" (read counts-table key ['count]))
    )

    (defun get-owner (nft-id:string)
        @doc "Returns the owner of a particular nft"
        (at "owner-address" (read mledger nft-id ['owner-address] ))
    )

    (defun get-all-owner-nfts (owner:string)
        @doc "Returns all nfts owned by one address"
        (select mledger ["nft-id"] (where "owner-address" (= owner)))
    )

    (defun get-wl-members ()
        @doc "Returns all addresses currently on the whitelist table"
        (keys wl)
    )

    (defun id-for-new-nft ()
        @doc "returns the next NFT id"
        (int-to-str 10 (get-count MINERS_CREATED_COUNT))
    )
)

(create-table wl)
(create-table counts-table)
(create-table price-table)
(create-table mledger)

(initialize)
