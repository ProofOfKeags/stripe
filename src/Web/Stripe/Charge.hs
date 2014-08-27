{-# LANGUAGE OverloadedStrings #-}

module Web.Stripe.Charge 
    ( -- * Charge Types
      Charge   (..)
    , ChargeId (..)  
      -- * API Functions
    , chargeCustomer
    , chargeCard
    , chargeCardByToken
    , getCharge
    , updateChargeDescription
    , captureCharge
    ) where

import           Control.Applicative
import           Data.Aeson
import           Data.Bool
import           Data.Monoid
import           Data.Text                       (Text)
import qualified Data.Text.Encoding              as T
import           Network.Http.Client
import           Web.Stripe.Client.Internal
import           Web.Stripe.Client.Util
import           Web.Stripe.Types

chargeCustomer :: CustomerId ->        -- ^ The ID of the customer to be charged
                  Currency ->          -- ^ Required, 3-letter ISO Code
                  Amount ->            -- ^ Required, Integer value of 100 represents $1 
                  Maybe Description -> -- ^ Optional, default is null
                  Stripe Charge
chargeCustomer customerId currency amount description = 
    createCharge currency amount description (Just customerId) 
    Nothing Nothing Nothing False
    Nothing Nothing Nothing Nothing 

chargeCardByToken :: TokenId ->           -- ^ The Token representative of a credit card
                     Currency ->          -- ^ Required, 3-letter ISO Code
                     Amount ->            -- ^ Required, Integer value of 100 represents $1 
                     Maybe Description -> -- ^ Optional, default is null
                     Stripe Charge
chargeCardByToken tokenId currency amount description = 
    createCharge currency amount description Nothing (Just tokenId) 
    Nothing Nothing True Nothing Nothing Nothing Nothing

chargeCard :: CardNumber ->        -- ^ Required, Credit Card Number
              ExpMonth ->          -- ^ Required, Expiration Month (i.e. 09)
              ExpYear ->           -- ^ Required, Expiration Year (i.e. 2018)
              CVC ->               -- ^ Required, CVC Number (i.e. 000)
              Currency ->          -- ^ Required, 3-letter ISO Code
              Amount ->            -- ^ Required, Integer value of 100 represents $1 
              Maybe Description -> -- ^ Optional, default is null
              Stripe Charge
chargeCard cardNumber expMonth expYear cvc currency amount description = 
    createCharge currency amount description
    Nothing Nothing Nothing Nothing True
    (Just cardNumber) (Just expMonth) 
    (Just expYear) (Just cvc)

createCharge :: Currency ->          -- ^ Required, 3-letter ISO Code
                Amount ->            -- ^ Required, Integer value of 100 represents $1 
                Maybe Description -> -- ^ Optional, default is nullo
                Maybe CustomerId ->  -- ^ Optional, either CustomerId or TokenId has to be specified
                Maybe TokenId ->     -- ^ Optional, either CustomerId or TokenId has to be specified
                Maybe StatementDescription -> -- ^ Optional, Arbitrary string to include on CC statements
                Maybe ReceiptEmail -> -- ^ Optional, Arbitrary string to include on CC statements
                Capture ->            -- ^ Optional, default is True 
                Maybe CardNumber ->
                Maybe ExpMonth ->
                Maybe ExpYear ->
                Maybe CVC ->
                Stripe Charge
createCharge (Currency currency)
             (Amount amount) 
             description 
             customerId
             tokenId
             statementDescription
             receiptEmail
             capture 
             cardNumber
             expMonth
             expYear
             cvc = callAPI request
  where request = StripeRequest POST url params
        url     = "charges"
        params  = [ (x,y) | (x, Just y) <- [ 
                     ("amount", Just $ toBS amount)
                   , ("customer", (\(CustomerId cid) -> T.encodeUtf8 cid) <$> customerId)
                   , ("currency", Just $ T.encodeUtf8 currency)
                   , ("description", (\(Description desc) -> T.encodeUtf8 desc) <$> description)
                   , ("receipt_email", (\(ReceiptEmail email) -> T.encodeUtf8 email) <$> receiptEmail)
                   , ("capture", Just $ bool "false" "true" capture)
                   , ("card[number]", (\(CardNumber c) -> toBS c) <$> cardNumber)
                   , ("card[exp_month]", (\(ExpMonth m) -> toBS m) <$> expMonth)
                   , ("card[exp_year]", (\(ExpYear y) -> toBS y) <$> expYear)
                   , ("card[cvc]", (\(CVC cvc) -> toBS cvc) <$> cvc)
                   ]
                  ]

getCharge :: ChargeId -> -- ^ The Charge to update
             Stripe Charge
getCharge (ChargeId charge) = callAPI request
  where request = StripeRequest GET url params
        url     = "charges" </> charge
        params  = []

updateChargeDescription :: ChargeId ->    -- ^ The Charge to update
                           Description -> -- ^ The Charge Description to update
                           Stripe Charge
updateChargeDescription (ChargeId chargeId) (Description description) 
    = callAPI request
  where request = StripeRequest POST url params
        url     = "charges" </> chargeId
        params  = [("description", T.encodeUtf8 description)]

captureCharge :: ChargeId ->           -- ^ The Charge to capture
                 Maybe Amount ->       -- ^ If Nothing the entire charge will be captured, otherwise the remaining will be refunded
                 Maybe ReceiptEmail -> -- ^ Email address to send this charge's receipt to
                 Stripe Charge
captureCharge (ChargeId chargeId) amount receiptEmail
    = callAPI request
  where request = StripeRequest POST url params
        url     = "charges" </> chargeId </> "capture" 
        params  = [ (x,y) | (x, Just y) <- [
                      ("amount", (\(Amount amount) -> toBS amount) <$> amount)
                    , ("receipt_email", (\(ReceiptEmail email) -> T.encodeUtf8 email) <$> receiptEmail)
                    ]
                  ]

getCharges :: Stripe (StripeList Charge)
getCharges = callAPI request
  where request = StripeRequest GET url params
        url     = "charges"
        params  = [ ("", "1") ]