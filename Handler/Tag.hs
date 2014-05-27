module Handler.Tag where

import Import

import View.Navbar (navbarWidget)

getTagR :: Text -> Handler Html
getTagR text = do
    Entity tagId _ <- runDB $ getBy404 (UniqueTagText text)
    resources      <- runDB $ getResourcesWithTagId tagId
    defaultLayout $ do
        setTitle "Tag"
        $(widgetFile "tag")

getResourcesWithTagId :: TagId -> SqlPersistT Handler [Entity Resource]
getResourcesWithTagId tagId = 
    select $ from $ \(resource, resourceTag) -> do
        where_ (resource^.ResourceId ==. resourceTag^.ResourceTagResourceId
            &&. resourceTag^.ResourceTagTagId ==. val tagId)
        return resource
