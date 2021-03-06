module View.Resource
    ( resourceForm
    , resourceTagsForm
    , resourceTypeField
    , resourceInfoWidget
    , resourceListWidget
    , resourceListItemWidget
    ) where

import Import

import           Data.Attoparsec.Text   (Parser, char, many1, notChar, sepBy1, skipSpace)
import           Data.Foldable          (Foldable)
import qualified Data.Set               as S
import           Data.Text              (intercalate, pack)
import           Data.Time              (getCurrentTime)
import           Yesod.Form.Bootstrap3  -- (renderBootstrap3)

import           Model.Resource         (getResourceTags, isFavoriteResource, isGrokkedResource)
import           Model.User             (unsafeGetUserById)
import           Yesod.Form.Types.Extra (parsedTextField)

-- A single form to input a Resource and its associated tags.
resourceForm :: UserId -> Form (Resource, Set Text)
resourceForm uid = renderBootstrap3 BootstrapInlineForm $ (,)
    <$> resourceEntityForm uid
    <*> resourceTagsForm Nothing
    <*  bootstrapSubmit ("Submit" :: BootstrapSubmit Text)

-- A form to input a Resource.
resourceEntityForm :: UserId -> AForm Handler Resource
resourceEntityForm uid = Resource
    <$> areq textField "Title" Nothing
    <*> areq urlField ("Url" {fsAttrs = [("placeholder", "http://")]}) Nothing
    <*> aopt textField "Primary Author (optional)" Nothing
    <*> aopt intField "Year (optional)" Nothing
    <*> areq resourceTypeField "Type" Nothing
    <*> pure uid
    <*> lift (liftIO getCurrentTime)

resourceTypeField :: Field Handler ResourceType
resourceTypeField = selectFieldList $ map (descResourceType &&& id) [minBound..maxBound]

-- A form to input a comma-separated list of tags.
resourceTagsForm :: Maybe (Set Text) -> AForm Handler (Set Text)
resourceTagsForm = areq (parsedTextField parseTags showTags) "Tags (comma separated)"
  where
    parseTags :: Parser (Set Text)
    parseTags = S.fromList <$> parseTag `sepBy1` char ','

    parseTag :: Parser Text
    parseTag = pack <$> token (many1 $ notChar ',')

    token :: Parser a -> Parser a
    token p = skipSpace *> p <* skipSpace

    showTags :: Set Text -> Text
    showTags = intercalate ", " . S.toAscList

-- Display meta-information about the resource.
resourceInfoWidget :: Entity Resource -> Widget
resourceInfoWidget (Entity resId res) = do
    tags <- handlerToWidget . runDB $ getResourceTags resId
    user <- handlerToWidget . unsafeGetUserById $ resourceUserId res
    $(widgetFile "resource-info")

resourceListWidget :: Foldable f => f (Entity Resource) -> Text -> Widget
resourceListWidget resources title = do
    setTitle $ toHtml title
    addScriptRemote "http://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js"
    $(widgetFile "resource-list")

resourceListItemWidget :: Entity Resource -> Widget
resourceListItemWidget (Entity resId res) = do
    is_logged_in <- maybe False (const True) <$> handlerToWidget maybeAuthId
    is_fav       <- handlerToWidget $ isFavoriteResource resId
    is_grokked   <- handlerToWidget $ isGrokkedResource resId
    [whamlet|
      <div .res-li>
        $if is_logged_in
          <div .res-li-col .res-fav :is_fav:.fav ##{toPathPiece resId} title="Favorite">
          <div .res-li-col .res-grok :is_grokked:.grok ##{toPathPiece resId} title="Grokked">
        $# The info (floated right) has to be rendered first, so the link can be sized properly.
        <a .res-li-col .res-info href=@{ResourceR resId}>

        $# TODO: DRY
        <a .res-li-col .res-link href=#{resourceUrl res}>#{resourceTitle res} #
          $maybe author <- resourceAuthor res
            <span .res-li-col .res-author >&mdash; #{author} #
          $maybe published <- resourcePublished res
            <span .res-li-col .res-published>(#{show published})
    |]
