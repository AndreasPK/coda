{-# language GADTs #-}
{-# language TypeFamilies #-}
{-# language DeriveGeneric #-}
{-# language PatternSynonyms #-}
{-# language FlexibleContexts #-}
{-# language DeriveTraversable #-}
{-# language OverloadedStrings #-}
{-# language DeriveDataTypeable #-}
{-# language GeneralizedNewtypeDeriving #-}

-----------------------------------------------------------------------------
-- |
-- Copyright   :  (C) 2017 Edward Kmett
-- License     :  BSD2 (see the file LICENSE.md)
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  experimental
-- Portability :  non-portable
--
-- JSON-RPC 2.0
--
-- http://www.jsonrpc.org/specification
-----------------------------------------------------------------------------

module Coda.Rpc.Base
  ( Id(..)
  , Request(..)
  , Response(..)
  , ResponseError(..)
  , ErrorCode
    ( ErrorCode
    , ParseError
    , InvalidRequest
    , MethodNotFound
    , InvalidParams 
    , InternalError
    , ServerErrorStart
    , ServerErrorEnd
    , ServerNotInitialized
    , UnknownErrorCode
    , RequestCancelled
    )
  ) where

import Control.Applicative
import Control.Monad
import Data.Aeson
import Data.Aeson.Encoding
import Data.Aeson.Types
import Data.Bifunctor
import Data.Bifoldable
import Data.Bitraversable
import Data.ByteString.Builder
import qualified Data.ByteString.Lazy as Lazy
import Data.Data
import Data.Ix
import Data.Monoid ((<>))
import Data.String
import Data.Text
import Data.Void
import GHC.Generics

--------------------------------------------------------------------------------
-- JSON-RPC 2.0
--------------------------------------------------------------------------------

jsonRpcVersion :: Text
jsonRpcVersion = fromString "2.0"

-- format a valid JsonRpc message
-- send :: ToJSON a => a -> Builder
-- send a = string7 "Content-Length: " <> intDec (Lazy.length content) <> string7 "\r\n\r\n" <> content where
--   content = toLazyByteString (fromEncoding (toEncoding a))

-- recieve a message, and give back any error messages we should reply with due to parse errors
-- this should be an interatee like thing
-- recv :: FromJSON a => Lazy.ByteString -> Either [Value] (a, Lazy.ByteString)
-- recv = parseHeaders

data JsonRpcHeader = JsonRpcContentType String
data JsonRpcHeaders = JsonRpcHeaders { jsonRpcContentLength :: !Int, jsonRpcHeaders :: [JsonRpcHeader]

parseHeaders :: StateT Lazy.ByteString (Either [Response Void Void]) Int
parseHeaders = StateT $ \s -> case stripPrefix "Content-" s of
  Nothing -> Left [Response Nothing Nothing (Just (ReponseError ParseError "Unknown header" Nothing))]
  Just s' -> case stripPrefix "Length: " s' of
    Just s'' -> case split '\r' s of 
    Just s'' ->  -- parse an integer
    Nothing -> case stripPrefix "Type: " s' of

parseHeaders :: Lazy.ByteString -> Either [Response Void Void] (Int, Lazy.ByteString)
parseHeaders 

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

infixr 8 ?=, !=, !~

class Monoid (Ob v) => From v where
  type Ob v :: *
  (!=) :: Text -> v -> Ob v

instance x ~ Value => From (Encoding' x) where
  type Ob (Encoding' x) = Series
  t != a       = pair t a
  
instance From Value where
  type Ob Value = [(Text, Value)]
  t != a       = [t .= a]

class Monoid t => To t where
  (!~) :: ToJSON v => Text -> v -> t

instance To Series where
 t !~ a       = pair t (toEncoding a)
  
instance x ~ (Text, Value) => To [x] where
 t !~ a = [t .= toJSON a]

(?=) :: From v => Text -> Maybe v -> Ob v
t ?= Just a  = t != a
_ ?= Nothing = mempty

--------------------------------------------------------------------------------
-- Id
--------------------------------------------------------------------------------

data Id 
  = IntId !Int
  | TextId !Text
  deriving (Eq, Ord, Show, Data, Generic)

instance ToJSON Id where
  toJSON (IntId i) = Number $ fromIntegral i
  toJSON (TextId s) = String s
  toEncoding (IntId i) = int i
  toEncoding (TextId s) = text s

instance FromJSON Id where
  parseJSON a = IntId  <$> parseJSON a
            <|> TextId <$> parseJSON a

instance IsString Id where
  fromString = TextId . fromString

--------------------------------------------------------------------------------
-- Request
--------------------------------------------------------------------------------

-- |
-- http://www.jsonrpc.org/specification#request_object
data Request a = Request
  { requestId     :: !Id
  , requestMethod :: !Text
  , requestParams :: !(Maybe a)
  } deriving (Eq, Ord, Show, Data, Generic, Functor, Foldable, Traversable)

instance FromJSON1 Request where
  liftParseJSON pa _ = withObject "Request" $ \v -> do
    ver <- v .: "jsonrpc" -- check for jsonprc validity
    guard (ver == jsonRpcVersion)
    Request <$> v .: "id"
            <*> v .: "method"
            <*> explicitParseFieldMaybe pa v "params"

instance ToJSON1 Request where
  liftToJSON sa _ (Request i m a)     = object $ 
    "jsonrpc" !~ jsonRpcVersion <> "id" !~ i <> "method" !~ m <> "params" ?= fmap sa a
  liftToEncoding sa _ (Request i m a) = pairs $
    "jsonrpc" !~ jsonRpcVersion <> "id" !~ i <> "method" !~ m <> "params" ?= fmap sa a

instance FromJSON a => FromJSON (Request a) where
  parseJSON = liftParseJSON parseJSON parseJSONList

instance ToJSON a => ToJSON (Request a) where
  toJSON = liftToJSON toJSON toJSONList
  toEncoding = liftToEncoding toEncoding toEncodingList

--------------------------------------------------------------------------------
-- Response
--------------------------------------------------------------------------------

-- |
-- http://www.jsonrpc.org/specification#response_object
data Response e a = Response
  { responseId     :: !(Maybe Id)
  , responseResult :: !(Maybe a)
  , responseError  :: !(Maybe (ResponseError e))
  } deriving (Eq, Ord, Show, Data, Generic, Functor, Foldable, Traversable)

instance ToJSON2 Response where
  liftToJSON2 se sle sa _ (Response i r e) = object $ 
       "jsonrpc" !~ jsonRpcVersion
    <> "id"      !~ i
    <> "result"  ?= fmap sa r
    <> "error"   ?= fmap (liftToJSON se sle) e

  liftToEncoding2 se sle sa _ (Response i r e) = pairs $
       "jsonrpc" !~ jsonRpcVersion
    <> "id"      !~ i
    <> "result"  ?= fmap sa r
    <> "error"   ?= fmap (liftToEncoding se sle) e

instance FromJSON2 Response where
  liftParseJSON2 pe ple pa _ = withObject "Response" $ \v -> do
    ver <- v .: "jsonrpc"
    guard (ver == jsonRpcVersion)
    Response
      <$> v .: "id"
      <*> explicitParseFieldMaybe pa v "result"
      <*> explicitParseFieldMaybe (liftParseJSON pe ple) v "error"

instance ToJSON e => ToJSON1 (Response e) where
  liftToJSON = liftToJSON2 toJSON toJSONList
  liftToEncoding = liftToEncoding2 toEncoding toEncodingList

instance FromJSON e => FromJSON1 (Response e) where
  liftParseJSON = liftParseJSON2 parseJSON parseJSONList

instance Bifunctor Response where
  bimap f g (Response i r e) = Response i (fmap g r) (fmap (fmap f) e)

instance Bifoldable Response where
  bifoldMap f g (Response _ r e) = foldMap g r <> foldMap (foldMap f) e

instance Bitraversable Response where
  bitraverse f g (Response i r e) = Response i <$> traverse g r <*> traverse (traverse f) e

--------------------------------------------------------------------------------
-- ErrorCode
--------------------------------------------------------------------------------

-- | Defined in http://www.jsonrpc.org/specification#error_object
newtype ErrorCode = ErrorCode Int
  deriving (Show, Eq, Ord, Read, Bounded, Ix, Data, Generic)

instance FromJSON ErrorCode where
  parseJSON v = ErrorCode <$> parseJSON v 

instance ToJSON ErrorCode where
  toJSON (ErrorCode e) = toJSON e
  toEncoding (ErrorCode e) = toEncoding e

pattern ParseError :: ErrorCode
pattern ParseError = ErrorCode (-32700)

pattern InvalidRequest :: ErrorCode
pattern InvalidRequest = ErrorCode (-32600)

pattern MethodNotFound :: ErrorCode
pattern MethodNotFound = ErrorCode (-32601)

pattern InvalidParams :: ErrorCode
pattern InvalidParams = ErrorCode (-32602)

pattern InternalError :: ErrorCode
pattern InternalError = ErrorCode (-32603)

pattern ServerErrorStart :: ErrorCode 
pattern ServerErrorStart = ErrorCode (-32099)

pattern ServerErrorEnd :: ErrorCode 
pattern ServerErrorEnd = ErrorCode (-32000)

pattern ServerNotInitialized :: ErrorCode
pattern ServerNotInitialized = ErrorCode (-32002)

pattern UnknownErrorCode :: ErrorCode
pattern UnknownErrorCode = ErrorCode (-32001);

pattern RequestCancelled :: ErrorCode
pattern RequestCancelled = ErrorCode (-32800);


--------------------------------------------------------------------------------
-- ResponseError
--------------------------------------------------------------------------------

-- | 
-- http://www.jsonrpc.org/specification#error_object
data ResponseError a = ResponseError
  { responseErrorCode    :: !ErrorCode
  , responseErrorMessage :: !Text
  , responseErrorData    :: !(Maybe a)
  } deriving (Eq, Ord, Show, Data, Generic, Functor, Foldable, Traversable)

instance FromJSON1 ResponseError where
  liftParseJSON pa _ = withObject "ResponseError" $ \v -> ResponseError
    <$> v .: "code"
    <*> v .: "message"
    <*> explicitParseFieldMaybe pa v "data"

instance ToJSON1 ResponseError where
  liftToJSON sa _ (ResponseError c m d) = object $
    "code" !~ c <> "message" !~ m <> "data" ?= fmap sa d
  liftToEncoding sa _ (ResponseError c m d) = pairs $
    "code" !~ c <> "message" !~ m <> "data" ?= fmap sa d

instance FromJSON a => FromJSON (ResponseError a) where
  parseJSON = liftParseJSON parseJSON parseJSONList

instance ToJSON a => ToJSON (ResponseError a) where
  toJSON = liftToJSON toJSON toJSONList
  toEncoding = liftToEncoding toEncoding toEncodingList

{-

--------------------------------------------------------------------------------
-- Position
--------------------------------------------------------------------------------

data Position = Position
  { positionLine :: !Int
  , positionCharacter :: !Int
  } deriving (Eq, Ord, Show, Data, Generic)

data Range = Range
  { rangeStart :: !Int
  , rangeEnd :: !Int
  } deriving (Eq, Ord, Show, Data, Generic)

data Location = Location
  { uri :: !DocumentUri
  , range :: !Range
  } deriving (Eq, Ord, Show, Data, Generic)

--------------------------------------------------------------------------------
-- DocumentUri
--------------------------------------------------------------------------------

type DocumentUri = Text

-}

