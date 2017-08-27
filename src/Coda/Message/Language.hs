{-# language LambdaCase #-}
{-# language ViewPatterns #-}
{-# language DeriveGeneric #-}
{-# language PatternSynonyms #-}
{-# language DeriveTraversable #-}
{-# language DeriveDataTypeable #-}
{-# language OverloadedStrings #-}
{-# language GeneralizedNewtypeDeriving #-}
--------------------------------------------------------------------------------
-- |
-- Copyright :  (c) Edward Kmett 2017
-- License   :  BSD2
-- Maintainer:  Edward Kmett <ekmett@gmail.com>
-- Stability :  experimental
-- Portability: non-portable
--
-- <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md Language Server Protocol>
--------------------------------------------------------------------------------
module Coda.Message.Language
  (
  -- * Cancellation Support
    pattern CancelRequest
  , _CancelRequest
  , pattern RequestCancelled
  , cancelledResponse
  -- * Language Server Protocol
  , DocumentUri
  , Position(..)
  , Range(..)
  , Location(..)
  , Diagnostic(..)
  , Command(..)
  , Command_
  , TextEdit(..)
  , TextDocumentIdentifier(..)
  , VersionedTextDocumentIdentifier(..)
  , TextDocumentItem(..)
  , TextDocumentEdit(..)
  , UriMap(..)
  , WorkspaceEdit(..)
  -- * Overloading
  , HasRange(..)
  , HasUri(..)
  , HasVersion(..)
  , HasTextDocumentIdentifier(..)
  , HasVersionedTextDocumentIdentifier(..)
  ) where

import Coda.Message.Base
import Coda.Util.Aeson
import Control.Lens.Operators ((<&>))
import Control.Lens.Combinators
import Coda.Message.Severity as Severity
import Control.Monad
import Data.Aeson hiding (Error)
import Data.Aeson.Encoding.Internal
import Data.Data
import Data.Hashable
import Data.Hashable.Lifted
import Data.HashMap.Strict as HashMap
import Data.Ix
import Data.Monoid
import Data.Text as Text
import GHC.Generics

--------------------------------------------------------------------------------
-- Cancellation Notification
--------------------------------------------------------------------------------

-- | Note: You should still reply to the item in question
--
-- <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#-cancellation-support>

pattern CancelRequest :: Id -> Notification Value
pattern CancelRequest identifier = Notification "$/cancelRequest" (Value_ identifier)

_CancelRequest :: Prism' (Notification Value) Id
_CancelRequest = prism' CancelRequest $ \case
  CancelRequest a -> Just a
  _ -> Nothing

pattern RequestCancelled :: ErrorCode
pattern RequestCancelled = ErrorCode (-32800)

-- We don't reply to the CancelRequest, as it is a notification, but we should
-- cause the computation that was cancelled to respond with something like this:
cancelledResponse :: Id -> Response Value Id Value
cancelledResponse i = Response i Null (Just (ResponseError RequestCancelled "request cancelled" Null))

--------------------------------------------------------------------------------
-- DocumentUri
--------------------------------------------------------------------------------

-- |
-- | <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#uri>

type DocumentUri = Text

class HasUri t where
  uri :: Lens' t DocumentUri

--------------------------------------------------------------------------------
-- Line Endings
--------------------------------------------------------------------------------

-- |
-- <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#text-documents>
--
-- @
-- export const EOL: string[] = ['\n', '\r\n', '\r'];
-- @

data LineEnding = LineEndingCR | LineEndingLF | LineEndingCRLF
  deriving (Eq, Ord, Show, Read, Ix, Enum, Bounded, Data, Generic)

instance ToJSON LineEnding where
  toJSON LineEndingCR   = String "\r"
  toJSON LineEndingLF   = String "\n"
  toJSON LineEndingCRLF = String "\r\n"
  toEncoding LineEndingCR   = string "\r"
  toEncoding LineEndingLF   = string "\n"
  toEncoding LineEndingCRLF = string "\r\n"

instance FromJSON LineEnding where
  parseJSON (String "\r")   = pure LineEndingCR
  parseJSON (String "\n")   = pure LineEndingLF
  parseJSON (String "\r\n") = pure LineEndingCRLF
  parseJSON _ = mzero

--------------------------------------------------------------------------------
-- Position
--------------------------------------------------------------------------------

-- |
-- <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#position>
--
-- @
-- interface 'Position' {
--   line: number;
--   character: number;
-- }
-- @

data Position = Position
  { positionLine      :: !Int -- ^ 0-based line number
  , positionCharacter :: !Int -- ^ 0-based count of utf-16 words (not code-points!)
  } deriving (Eq, Ord, Show, Read, Data, Generic)

instance ToJSON Position where
  toJSON     (Position l c) = object $ "line" !~ l <> "character" !~ c
  toEncoding (Position l c) = pairs  $ "line" !~ l <> "character" !~ c

instance FromJSON Position where
  parseJSON = withObject "Position" $ \v -> Position
    <$> v .: "line"
    <*> v .: "character"

instance Hashable Position

--------------------------------------------------------------------------------
-- Range
--------------------------------------------------------------------------------

-- |
-- <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#range>
--
-- @
-- interface 'Range' {
--   start: 'Position';
--   end: 'Position';
-- }
-- @
data Range = Range
  { _rangeStart :: !Position
  , _rangeEnd   :: !Position
  } deriving (Eq, Ord, Show, Read, Data, Generic)

instance ToJSON Range where
  toJSON     (Range s e) = object $ "start" !~ s <> "end" !~ e
  toEncoding (Range s e) = pairs  $ "start" !~ s <> "end" !~ e

class HasRange t where
  range :: Lens' t Range

instance HasRange Range where
  range = id

instance FromJSON Range where
  parseJSON = withObject "Range" $ \v -> Range
    <$> v .: "start"
    <*> v .: "end"

instance Hashable Range

--------------------------------------------------------------------------------
-- Location
--------------------------------------------------------------------------------

-- |
-- <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#location>
--
-- @
-- interface 'Location' {
--   uri: 'DocumentUri';
--   range: 'Range';
-- }
-- @
data Location = Location
  { locationUri   :: DocumentUri
  , locationRange :: Range
  } deriving (Eq, Ord, Show, Read, Data, Generic)

instance ToJSON Location where
  toJSON     (Location u r) = object $ "uri" !~ u <> "range" !~ r
  toEncoding (Location u r) = pairs $ "uri" !~ u <> "range" !~ r

instance FromJSON Location where
  parseJSON = withObject "Location" $ \v -> Location
    <$> v .: "uri"
    <*> v .: "range"

instance Hashable Location

instance HasUri Location where
  uri f (Location u r) = f u <&> \u' -> Location u' r

instance HasRange Location where
  range f (Location u r) = Location u <$> f r

--------------------------------------------------------------------------------
-- Diagnostic
--------------------------------------------------------------------------------

-- |
-- <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#diagnostic>
--
-- @
-- interface 'Diagnostic' {
--   range: 'Range';
--   severity?: number;
--   code?: number | string;
--   source?: string;
--   message: string;
-- }
-- @
data Diagnostic = Diagnostic
  { diagnosticRange    :: !Range
  , diagnosticSeverity :: !(Maybe Severity)
  , diagnosticCode     :: !(Maybe Id)
  , diagnosticSource   :: !(Maybe Text)
  , diagnosticMessage  :: !Text
  } deriving (Eq, Ord, Show, Read, Data, Generic)

instance ToJSON Diagnostic where
  toJSON (Diagnostic r s c f m)    = object $
    "range" !~ r <> "severity" ?~ s <> "code" ?~ c <> "source" ?~ f <> "message" !~ m
  toEncoding (Diagnostic r s c f m) = pairs $
    "range" !~ r <> "severity" ?~ s <> "code" ?~ c <> "source" ?~ f <> "message" !~ m

instance FromJSON Diagnostic where
  parseJSON = withObject "Diagnostic" $ \v -> Diagnostic
    <$> v .: "range"
    <*> v .:? "severity"
    <*> v .:? "code"
    <*> v .:? "source"
    <*> v .: "message"

instance Hashable Diagnostic

instance HasRange Diagnostic where
  range f w = f (diagnosticRange w) <&> \r' -> w { diagnosticRange = r' }

--------------------------------------------------------------------------------
-- Command
--------------------------------------------------------------------------------

-- |
-- <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#command>
--
-- @
-- interface 'Command' {
--   title : string;
--   command: string;
--   arguments?: any[]
-- }
-- @

data Command a = Command
  { commandTitle :: Text
  , commandCommand :: Text
  , commandArguments :: Maybe [a]
  } deriving (Eq, Ord, Show, Read, Data, Generic, Generic1, Functor, Foldable, Traversable)

type Command_ = Command Value

instance ToJSON a => ToJSON (Command a) where
  toJSON (Command t c a) = object $
    "title" !~ t <> "command" !~ c <> "arguments" ?~ a
  toEncoding (Command t c a) = pairs $
    "title" !~ t <> "command" !~ c <> "arguments" ?~ a

instance FromJSON a => FromJSON (Command a) where
  parseJSON = withObject "Command" $ \v -> Command
    <$> v .: "title"
    <*> v .: "command"
    <*> v .:? "arguments"

instance Hashable1 Command

instance Hashable a => Hashable (Command a) where
  hashWithSalt = hashWithSalt1

--------------------------------------------------------------------------------
-- TextEdit
--------------------------------------------------------------------------------

-- | <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#textedit>
--
-- @
-- interface 'TextEdit' {
--   range: 'Range';
--   newText: string;
-- }
-- @
data TextEdit = TextEdit
  { textEditRange :: Range
  , textEditNewText :: Text
  } deriving (Eq,Ord,Show,Read,Data,Generic)

instance ToJSON TextEdit where
  toJSON (TextEdit r t) = object $
    "range" !~ r <> "newText" !~ t
  toEncoding (TextEdit r t) = pairs $
    "range" !~ r <> "newText" !~ t

instance FromJSON TextEdit where
  parseJSON = withObject "TextEdit" $ \v -> TextEdit
    <$> v .: "range"
    <*> v .: "newText"

instance Hashable TextEdit

--------------------------------------------------------------------------------
-- TextDocumentIdentifier
--------------------------------------------------------------------------------

-- | <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#textdocumentidentifier>
--
-- @
-- interface 'TextDocumentIdentifier' {
--   uri : 'DocumentUri'
-- }
-- @
newtype TextDocumentIdentifier = TextDocumentIdentifier
  { textDocumentIdentifierUri :: DocumentUri
  } deriving (Eq, Ord, Show, Read, Data, Generic)

instance ToJSON TextDocumentIdentifier where
  toJSON (TextDocumentIdentifier u) = object $ "uri" !~ u
  toEncoding (TextDocumentIdentifier u) = pairs $ "uri" !~ u

instance FromJSON TextDocumentIdentifier where
  parseJSON = withObject "TextDocumentIdentifier" $ \v -> TextDocumentIdentifier <$> v .: "uri"

instance Hashable TextDocumentIdentifier

instance HasUri TextDocumentIdentifier where
  uri f (TextDocumentIdentifier i) = TextDocumentIdentifier <$> f i

-- |
-- Law:
--
-- @
-- 'uri' = 'textDocumentIdentifier' '.' 'uri'
-- @
class HasUri t => HasTextDocumentIdentifier t where
  textDocumentIdentifier :: Lens' t TextDocumentIdentifier

instance HasTextDocumentIdentifier TextDocumentIdentifier where
  textDocumentIdentifier = id

--------------------------------------------------------------------------------
-- VersionTextDocumentIdentifier
--------------------------------------------------------------------------------

-- | <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#versionedtextdocumentidentifier>
--
-- @
-- interface 'VersionedTextDocumentIdentifier' extends 'TextDocumentIdentifier' {
--   version: number;
-- }
-- @
data VersionedTextDocumentIdentifier = VersionedTextDocumentIdentifier
  { versionedTextDocumentIdentifierUri :: !DocumentUri
  , versionedTextDocumentIdentifierVersion :: !Int
  } deriving (Eq, Ord, Show, Read, Data, Generic)

class HasVersion t where
  version :: Lens' t Int

instance HasVersion VersionedTextDocumentIdentifier where
  version f (VersionedTextDocumentIdentifier u i) = VersionedTextDocumentIdentifier u <$> f i

instance HasUri VersionedTextDocumentIdentifier where
  uri f (VersionedTextDocumentIdentifier u i) = f u <&> \u' -> VersionedTextDocumentIdentifier u' i

instance HasTextDocumentIdentifier VersionedTextDocumentIdentifier where
  textDocumentIdentifier f (VersionedTextDocumentIdentifier u i) = f (TextDocumentIdentifier u) <&>
    \ (TextDocumentIdentifier u') -> VersionedTextDocumentIdentifier u' i

instance ToJSON VersionedTextDocumentIdentifier where
  toJSON (VersionedTextDocumentIdentifier u i) = object $
    "uri" !~ u <> "version" !~ i
  toEncoding (VersionedTextDocumentIdentifier u i) = pairs $
    "uri" !~ u <> "version" !~ i

instance FromJSON VersionedTextDocumentIdentifier where
  parseJSON = withObject "VersionedTextDocumentIdentifier" $ \v -> VersionedTextDocumentIdentifier
    <$> v .: "uri"
    <*> v .: "version"

instance Hashable VersionedTextDocumentIdentifier

-- |
-- Laws:
--
-- @
-- 'textDocumentIdentifier' = 'versionedTextDocumentIdentifier' '.' 'textDocumentIdentifier'
-- 'version' = 'versionedTextDocumentIdentifier' '.' 'version'
-- @
class (HasVersion t, HasTextDocumentIdentifier t) => HasVersionedTextDocumentIdentifier t where
  versionedTextDocumentIdentifier :: Lens' t VersionedTextDocumentIdentifier

instance HasVersionedTextDocumentIdentifier VersionedTextDocumentIdentifier where
  versionedTextDocumentIdentifier = id

--------------------------------------------------------------------------------
-- TextDocumentEdit
--------------------------------------------------------------------------------

data TextDocumentEdit = TextDocumentEdit
  { textDocumentEditTextDocument :: !VersionedTextDocumentIdentifier
  , textDocumentEditEdits :: [TextEdit]
  } deriving (Eq, Ord, Show, Read, Data, Generic)

instance ToJSON TextDocumentEdit where
  toJSON (TextDocumentEdit i es) = object $
    "textDocument" !~ i <> "edits" !~ es
  toEncoding (TextDocumentEdit i es) = pairs $
    "textDocument" !~ i <> "edits" !~ es

instance FromJSON TextDocumentEdit where
  parseJSON = withObject "TextDocumentEdit" $ \v -> TextDocumentEdit
    <$> v .: "textDocument"
    <*> v .: "edits"

instance Hashable TextDocumentEdit

instance HasUri TextDocumentEdit where
  uri = versionedTextDocumentIdentifier.uri

instance HasTextDocumentIdentifier TextDocumentEdit where
  textDocumentIdentifier = versionedTextDocumentIdentifier.textDocumentIdentifier

instance HasVersion TextDocumentEdit where
  version = versionedTextDocumentIdentifier.version

instance HasVersionedTextDocumentIdentifier TextDocumentEdit where
  versionedTextDocumentIdentifier f (TextDocumentEdit v es) =
    f v <&> \v' -> TextDocumentEdit v' es

--------------------------------------------------------------------------------
-- WorkspaceEdit
--------------------------------------------------------------------------------

newtype UriMap a = UriMap { runUriMap :: HashMap Text a }
  deriving (Eq, Show, Read, Functor, Data, Generic, Generic1, Foldable, Traversable, Hashable1, Hashable)

instance ToJSON1 UriMap where
  liftToJSON sa _ (UriMap hm) = object $ HashMap.foldrWithKey (\k v m -> (k, sa v) : m) [] hm
  liftToEncoding sa _ (UriMap hm) = pairs $ HashMap.foldrWithKey (\k v m -> pair k (sa v) <> m) mempty hm

instance ToJSON a => ToJSON (UriMap a) where
  toJSON = toJSON1
  toEncoding = toEncoding1

data WorkspaceEdit = WorkspaceEdit
  { workspaceEditChanges :: !(Maybe (UriMap [TextEdit])) -- object mapping uris to [TextEdit]
  , workspaceEditDocumentChanges :: !(Maybe [TextDocumentEdit])
  } deriving (Eq, Show, Read, Data, Generic)

--------------------------------------------------------------------------------
-- TextDocumentItem
--------------------------------------------------------------------------------

-- | An item to transfer a text document from the client to the server.
--
-- <https://github.com/Microsoft/language-server-protocol/blob/master/protocol.md#textdocumentitem>
--
-- @
-- interface TextDocumentItem {
--   uri: DocumentUri;
--   languageId: string;
--   version: number;
--   text: string;
-- }
-- @
data TextDocumentItem = TextDocumentItem
  { textDocumentItemUri :: !DocumentUri
  , textDocumentItemLanguageId :: !Text
  , textDocumentItemVersion :: !Int
  , textDocumentItemText :: !Text
  } deriving (Eq, Ord, Show, Read, Data, Generic)

instance Hashable TextDocumentItem

instance ToJSON TextDocumentItem where
  toJSON (TextDocumentItem u l v t) = object $
    "uri" !~ u <> "languageId" !~ l <> "version" !~ v <> "text" !~ t
  toEncoding (TextDocumentItem u l v t) = pairs $
    "uri" !~ u <> "languageId" !~ l <> "version" !~ v <> "text" !~ t

instance FromJSON TextDocumentItem where
  parseJSON = withObject "TextDocumentItem" $ \v -> TextDocumentItem
    <$> v .: "uri"
    <*> v .: "languageId"
    <*> v .: "version"
    <*> v .: "text"

instance HasUri TextDocumentItem where
  uri f t = f (textDocumentItemUri t) <&> \u' -> t { textDocumentItemUri = u' }

instance HasVersion TextDocumentItem where
  version f t = f (textDocumentItemVersion t) <&> \v' -> t { textDocumentItemVersion = v' }

-- | morally exists
instance HasTextDocumentIdentifier TextDocumentItem where
  textDocumentIdentifier f (TextDocumentItem u l v t)
     = f (TextDocumentIdentifier u) <&> \(TextDocumentIdentifier u') -> TextDocumentItem u' l v t

-- | morally exists
instance HasVersionedTextDocumentIdentifier TextDocumentItem where
  versionedTextDocumentIdentifier f (TextDocumentItem u l v t)
     = f (VersionedTextDocumentIdentifier u v) <&> \(VersionedTextDocumentIdentifier u' v') -> TextDocumentItem u' l v' t

--------------------------------------------------------------------------------
-- TextDocumentPositionParams
--------------------------------------------------------------------------------
