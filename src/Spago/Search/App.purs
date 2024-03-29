module Spago.Search.App where

import Prelude

import Spago.Search.App.SearchField as SearchField
import Spago.Search.App.SearchResults as SearchResults
import Spago.Search.Extra (whenJust)

import Control.Coroutine as Coroutine
import Data.Maybe (Maybe(..))
import Data.Newtype (wrap)
import Effect (Effect)
import Halogen as H
import Halogen.Aff as HA
import Halogen.VDom.Driver (runUI)
import Web.DOM.Document as Document
import Web.DOM.Element as Element
import Web.DOM.Node as Node
import Web.DOM.ParentNode as ParentNode
import Web.DOM.Text as Text
import Web.HTML as HTML
import Web.HTML.HTMLDocument as HTMLDocument
import Web.HTML.HTMLElement (fromElement)
import Web.HTML.Window as Window

main :: Effect Unit
main = do
  win <- HTML.window
  doc <- HTMLDocument.toDocument <$> Window.document win

  insertStyle doc
  mbContainers <- getContainers doc

  whenJust mbContainers \ { searchField, searchResults, pageContents } -> do
    HA.runHalogenAff do
      sfio <- runUI SearchField.component unit searchField
      srio <- runUI (SearchResults.mkComponent pageContents) unit searchResults
      sfio.subscribe $
        Coroutine.consumer (srio.query <<< H.tell <<< SearchResults.MessageFromSearchField)

insertStyle :: Document.Document -> Effect Unit
insertStyle doc = do
  let styleContents = """
  .top-banner__actions {
    width: 10%;
  }
  .load_more {
    margin-top:2em;
  }
  .load_more p {
    font-style:italic
  }
  .load_more a {
    background:#eee;
    padding:0.4em
  }
  #load-more-link {
    cursor: pointer;
  }
  .result {
    font-size: 1.25em;
  }
  .result__body .keyword, .result__body .syntax {
    color: #0B71B4;
  }
  """
  mbHead <-
    ParentNode.querySelector (wrap "head") (Document.toParentNode doc)

  whenJust mbHead \head -> do

    contents <- Document.createTextNode styleContents doc
    style <- Document.createElement "style" doc
    void $ Node.appendChild (Text.toNode contents) (Element.toNode style)
    void $ Node.appendChild (Element.toNode style) (Element.toNode head)

getContainers :: Document.Document -> Effect (Maybe { searchField :: HTML.HTMLElement
                                                    , searchResults :: HTML.HTMLElement
                                                    , pageContents :: Element.Element })
getContainers doc = do
  let docPN = Document.toParentNode doc
  mbBanner <-
    ParentNode.querySelector (wrap ".top-banner > .container") docPN
  mbEverything <-
    ParentNode.querySelector (wrap ".everything-except-footer") docPN
  mbContainer <-
    ParentNode.querySelector (wrap ".everything-except-footer > .container") docPN
  case mbBanner, mbEverything, mbContainer of
    Just banner, Just everything, Just pageContents -> do
      search <- Document.createElement "div" doc
      void $ Node.appendChild (Element.toNode search) (Element.toNode banner)
      pure $ fromElement search     >>= \searchField ->
             fromElement everything >>= \searchResults ->
             pure { searchField, searchResults, pageContents }
    _, _, _ ->
      pure Nothing
