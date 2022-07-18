(namespace "free")

;; For more information about keysets checkout:
;; https://pact-language.readthedocs.io/en/latest/pact-reference.html#keysets-and-authorization
(define-keyset 'KMC-testnet-mint-1212 (read-keyset "KMC-testnet-mint-1212"))


(module KMC_testnet_mint3 'KMC-testnet-mint-1212
  @doc "Kadena Mining Club testnet mint contract."
    (use coin)

; ============================================
; ==               CONSTANTS                ==
; ============================================

    (defconst ADMIN_KEYSET (read-keyset 'KMC-testnet-mint-1212))
    (defconst ACCOUNTS_CREATED_COUNT "accounts created")
    (defconst MINERS_CREATED_COUNT "miners-count")
    (defconst MINER_URIS_CREATED_COUNT "miner-uris")
    (defconst FOUNDERS_CREATED_COUNT "founders-count")
    (defconst WHITELIST_MINTED_COUNT "whitelist-minted-count")

    (defconst WL_KD2_ROLE "wl-kd2-role") ; lets user mint 1 NFT at discounted price
    (defconst WL_KD5_ROLE "wl-kd5-role") ; lets user mint 2 NFTs at discounted price
    (defconst WL_KD6_ROLE "wl-kd6-role") ; lets user mint 3 NFTs at discounted price
    (defconst WL_KD7_ROLE "wl-kd7-role") ; lets user mint 5 NFTs at discounted price
    (defconst WL_KD8_ROLE "wl-kd8-role") ; lets user mint 10 NFT at discounted price

    (defconst PRICE_KEY "price-key")
    (defconst WHITELIST_PRICE_KEY "whitelist-price-key")
    (defconst FOUNDERS_PRICE_KEY "founders-price-key")
    (defconst MINERS_URI_KEY "miners-uri-key")
    (defconst ADMIN_ADDRESS "k:ab7cef70e1d91a138b8f65d26d6917ffcb852b84525b7dc2193843e8dfebf799")
    (defconst MAX_SUPPLY 10000 "The max supply of generation 0 miners")
    (defconst WHITELIST_MAX_MINT 1500 "The maximum number of mints that can be done at the whitelist price")
    (defconst FOUNDERS_MAX_SUPPLY 100 "The maximum supply of the founders pass NFTs")
    (defconst MINT_WALLET "k:ab7cef70e1d91a138b8f65d26d6917ffcb852b84525b7dc2193843e8dfebf799") ;;placeholder for payments contract

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

    (defcap FOUNDERS_OWNER (account:string id:string)
        @doc "Enforces that an account owns the particular miner ID"
        (let
            (
                (nft-owner (at "owner-address" (read fledger id ["owner-address"])))
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
        @doc "Keeps track of how many things there are."
        count:integer
    )

    (defschema price-schema
        @doc "Stores the price of each type of NFT or upgrade"
        price:decimal
    )

    (defschema uri-schema
        @doc "A schema to store all URIs before mint"
        uri:string
    )

    (defschema user-account-schema
        account-address:string
        id:string
        free-mint-count:integer
        guard:guard
        whitelist-mints-completed:integer
    )

    ;every entry is one NFT, to be stored on the ledger "fledger" for "Founders Ledger"
    (defschema fentry
        founders-nft-id:string
        owner-address:string
        uri:string
    )

    ; every entry is one NFT, to be stored on the ledger "mledger"
    (defschema entry
        nft-id:string
        generation:integer
        owner-address:string
        uri:string
        hashrate:decimal ;hashrate is only updated once per payment cycle
        tied-asic:string
        staked:integer ;0 for unstaked, 1 for staked
    )

    (deftable wl:{wl-schema})
    (deftable miner-uri-table:{uri-schema})
    (deftable mledger:{entry}) ;mledger stands for Miners Ledger. Contains info for all 10,000 Miners
    (deftable fledger:{fentry})
    (deftable counts-table:{counts-schema})
    (deftable price-table:{price-schema})
    (deftable user-accounts-table:{user-account-schema})

    (defun initialize ()
        @doc "Initialize the module the first time it is deployed" ; uncomment this for new contract deployment
        (insert counts-table ACCOUNTS_CREATED_COUNT {"count": 0})
        (insert counts-table MINERS_CREATED_COUNT {"count": 0})
        (insert counts-table FOUNDERS_CREATED_COUNT {"count": 0})
        (insert counts-table WHITELIST_MINTED_COUNT {"count": 0})
        (insert counts-table MINER_URIS_CREATED_COUNT {"count": 0})
        (insert price-table PRICE_KEY {"price": 0.3})
        (insert price-table FOUNDERS_PRICE_KEY {"price": 0.2})
        (insert price-table WHITELIST_PRICE_KEY {"price": 0.1})
    )

; ============================================
; ==              MINT FUNCTIONS            ==
; ============================================

    (defun mint-founders-pass ( account:string amount:decimal )
    ; need to make sure that only one pass can be purchased per wallet
        @doc "Mint a founders pass"
        (with-capability (ACCOUNT_GUARD account)
            (enforce-only-one-founder-pass account)
            (with-default-read counts-table FOUNDERS_CREATED_COUNT
                { 'count: 0.0 }
                { 'count := current-count }
                (enforce (> FOUNDERS_MAX_SUPPLY current-count ) (format "current-supply is {}" [current-count]))
            )
            (with-default-read price-table FOUNDERS_PRICE_KEY
              { 'price: 0.0 }
              { 'price := price_1 }
              (enforce (= amount price_1) (format "price {} is incorrect" [price_1]))
            )
            (validate-account-id account)
            (enforce-coin-account-exists account)
            (coin.transfer account ADMIN_ADDRESS amount)
            (write fledger account
                { "founders-nft-id" : (id-for-next-key FOUNDERS_CREATED_COUNT)
                , "owner-address"   : account
                , "uri"             : "PLACEHOLDER" })
            (with-capability (PRIVATE) (increase-count FOUNDERS_CREATED_COUNT))
            (format "1 Founder purchased for {} KDA." [amount])
        )
    )

    ; (defun mint-founders-bulk ( account:string amount:integer )

    ; )

    ; (defun mint-miners-bulk ( account:string amount:integer )

    ; )

    (defun mint-miner ( account:string amount:decimal) ;add guard:guard
        @doc "Mint a miner"
        ; (with-capability (ACCOUNT_GUARD account)
        ; ; when checking for whitelist, if no account exists, create one
        ;     (create-account account)
        ; make sure the counts are all incremented or decremented. whitelist, free mint, all the shit

            (let
                (
                    (price  (if (and (< (get-count WHITELIST_MINTED_COUNT) WHITELIST_MAX_MINT)
                                (> (get-remaining-whitelist-mints account) 0)) (get-price WHITELIST_PRICE_KEY) (get-price PRICE_KEY)))
                )
                (let
                    (
                        (price2 (if (> (get-user-free-mint-count account) 0) 0 price)) ;if they have a free mint, price is 0, else price is price from above
                    )
                    (enforce-rules account amount (get-count MINERS_CREATED_COUNT) MAX_SUPPLY price2)
                    (coin.transfer account ADMIN_ADDRESS amount)
                    (let
                        (
                            (id-for-new-miner (id-for-next-key MINERS_CREATED_COUNT))
                        )
                        (write mledger id-for-new-miner
                            { "nft-id"        : id-for-new-miner
                            , "generation"    : 1
                            , "owner-address" : account
                            , "uri"           : (with-capability (PRIVATE) (get-initialized-miner-uri id-for-new-miner))
                            , "hashrate" : 1.0
                            , "tied-asic"     : "" ;this will be null for all NFTs until ASIC delivery, must be updated by admin
                            , "staked"     : "0"
                            , "staked-unstaked" : "" })
                        (with-capability (PRIVATE) (increase-count MINERS_CREATED_COUNT))
                        (format "1 Miner purchased for {} KDA." [amount])
                    )
                )
            )
            ;; (let ((cur_guard (coin-account-guard account)))
            ;;     (enforce (= cur_guard guard) "KMC Account guards must match coin account guards")
            ;; )
        ; )
    )

    ;current-supply inputs are either MINERS_CREATED_COUNT or FOUNDERS_CREATED_COUNT
    (defun enforce-rules (account:string amount:decimal current-supply:integer max-supply:integer price:decimal )
        @doc "Checks to make sure max supply is not exceeded, the correct amount of KDA is sent, and validates the account of the sender"
        (enforce (> max-supply current-supply ) "All NFTs have been minted, check the marketplace for NFTs that are up for sale.")
        (enforce (= amount price) "The amount sent does not match the price {} of KDA required" [price])
        (validate-account-id account)
        (enforce-coin-account-exists account)
    )

; ============================================
; ==       State-modifying functions        ==
; ============================================

    (defun create-account (account:string)
        @doc "Creates an account"
        (enforce-coin-account-exists account)
        (with-capability (ACCOUNT_GUARD account)
            (let ((id (id-for-next-key ACCOUNTS_CREATED_COUNT)))
                (insert user-accounts-table account
                    { "free-mint-count" : 0
                    , "guard"   : (coin-account-guard account)
                    , "id"      : id ;also the same as the key
                    , "account-address" : account
                    , "whitelist-mints-completed": 0
                    }
                )
                (with-capability (PRIVATE) (increase-count ACCOUNTS_CREATED_COUNT))
            )
        )
    )

    (defun collect-uri-single (uri:string)
        @doc "Inserts a single URI into the uri-table"
        ; Cannot be called directly
        (require-capability (ADMIN))
        (let (
            (id (int-to-str 10 (get-count MINER_URIS_CREATED_COUNT))))
            (insert miner-uri-table id {"uri": uri })
            (with-capability (PRIVATE) (increase-count MINER_URIS_CREATED_COUNT))
        )
    )

    (defun collect-uri-multiple (uri-list:list)
        @doc "Takes a list of URIs and adds them all to the miner-uri table"
        ; pass in a list like this ["https://test1.com",https://test2.com",...]
        (with-capability (ADMIN)
            (map
                (collect-uri-single)
                uri-list
            )
        )
    )

    (defun read-uri (id:string) ;test this
        (with-capability (PRIVATE)
            (at "uri" (read miner-uri-table id ['uri] ))
        )
    )

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
        @doc "Allows the admin to update the ASIC tied to an NFT, format xxxxx:xxxxx,xxxxx:xxxxx"
        ; asic number 188, chip number 16 would look like 00188:00016
        ; multiple asics can be assigned with a comma between each
        (with-capability (ADMIN)
            (update mledger nft-id {"tied-asic": asic-num})
        )
    )

    (defun set-miner-uri (nft-id:integer new-uri:string)
        @doc "Allows the admin to update the URI for a NFT"
        (with-capability (ADMIN)
            (update mledger nft-id {"uri": new-uri})
        )
    )

    (defun set-hashrate (nft-id:integer new-hashrate:decimal)
        @doc "Allows the admin to update the hashrate for a NFT"
        ; this will eventually be used by the payments contract
        (with-capability (ADMIN)
            (update mledger nft-id {"hashrate": new-hashrate})
        )
    )


; ============================================
; ==     NON STATE-MODIFYING FUNCTIONS      ==
; ============================================

    (defun get-miner-details:string (nft-id:string)
        @doc "Returns the details of a miner NFT"
        {
          "nft-id" : (at "nft-id" (read mledger nft-id ['nft-id] ))
        , "generation" : (at "generation" (read mledger nft-id ['generation] ))
        , "owner-address" : (at "owner-address" (read mledger nft-id ['owner-address] ))
        , "uri" : (at "uri" (read mledger nft-id ['uri] ))
        , "hashrate" : (at "hashrate" (read mledger nft-id ['hashrate] ))
        , "tied-asic" : (at "tied-asic" (read mledger nft-id ['tied-asic] ))
        , "staked" : (at "staked" (read mledger nft-id ['staked] ))
        , "staked-unstaked" : (at "staked-unstaked" (read mledger nft-id ['staked-unstaked] ))
        }
    )

    (defun get-initialized-miner-uri (id:string)
        (require-capability (PRIVATE)
            (at "uri" (read miner-uri-table id ['uri]))
        )
    )

    (defun get-remaining-whitelist-mints:integer (user-account:string)
        @doc "Reads the number of whitelist mints completed and compares it to their role-allocated mints"
        (let
            (
                (completed-mints (at "whitelist-mints-completed" (read user-accounts-table user-account ["whitelist-mints-completed"])))
                (allowed-mints (return-role-mints user-account))
            )
            (let
                (
                    (remaining-whitelist-mints (- allowed-mints completed-mints))
                )
                remaining-whitelist-mints
            )
        )
    )

    (defun return-role-mints:integer (user-account:string)
        @doc "Determines how many mints each role is allowed for whitelist"
        (let
            (
                (role (at "role" (read wl user-account ["role"])))
            )
            (if (= role WL_KD2_ROLE) 1
            (if (= role WL_KD5_ROLE) 2
            (if (= role WL_KD6_ROLE) 3
            (if (= role WL_KD7_ROLE) 5
            (if (= role WL_KD7_ROLE) 10 0))))) ;0 is the catchall for if the role somehow does not exist
        )
    )

    (defun get-price (price-key:decimal) ;update this to support multiple prices
        ; gets the price for a key
        (at "price" (read price-table price-key ["price"]))
    )

    (defun get-count (key:string)
        ;gets the count for a key
        (at "count" (read counts-table key ['count]))
    )

    (defun get-owner-mledger (nft-id:string)
        @doc "Returns the owner of a particular miner in the Miner Ledger"
        (at "owner-address" (read mledger nft-id ['owner-address]))
    )

    (defun get-user-free-mint-count:integer (account:string)
        @doc "Returns the number of free mints that a user is entitled to"
        (at "free-mint-count" (read user-accounts-table account ['free-mint-count]))
    )

    (defun get-user-miners (owner:string)
        @doc "Returns all miners owned by one address"
        (select mledger ["nft-id"] (where "owner-address" (= owner)))
    )

    (defun get-wl-members ()
        @doc "Returns all addresses currently on the miner whitelist table"
        (keys wl)
    )

    (defun id-for-new-miner ()
        @doc "returns the next Miner NFT id"
        (int-to-str 10 (get-count MINERS_CREATED_COUNT))
    )

    (defun id-for-next-key (key:string)
        @doc "returns the next id for a given key"
        (int-to-str 10 (get-count key))
    )

    (defun get-founders-keys ()
        (keys fledger)
    )

    (defun enforce-only-one-founder-pass (address:string)
        @doc "Enforces only one founder pass per address"
        (let
            (
                (owned-count (length (select fledger ["owner-address"] (where "owner-address" (= address)))))
            )
            (enforce (<= owned-count 1) "You may only mint one Founder's Pass")
        )
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
)


; (create-table wl)
; (create-table miner-uri-table)
; (create-table mledger)
; (create-table fledger)
; (create-table counts-table)
; (create-table price-table)
; (create-table user-accounts-table)
; (initialize)
