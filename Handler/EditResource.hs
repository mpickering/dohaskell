module Handler.EditResource where

import Import

import qualified Data.Set          as S
import           Data.Text         (intercalate)
import           Database.Persist.Sql

import           Model.Resource    (getResourceTags, updateResource)
import           Model.User        (thisUserHasAuthorityOver)
import           View.EditResource (editResourceForm)

postEditResourceR :: ResourceId -> Handler Html
postEditResourceR resId = do
    res <- runDB $ get404 resId
    ((result, _), _) <- runFormPost (editResourceForm Nothing Nothing Nothing Nothing Nothing)
    case result of
        FormSuccess (newTitle, newAuthor, newPublished, newType, newTags) -> do
            ok <- thisUserHasAuthorityOver (resourceUserId res)
            if ok
                then do
                    runDB $ updateResource
                                resId
                                newTitle
                                newAuthor
                                newPublished
                                newType
                                (map Tag . S.toAscList $ newTags)
                    setMessage "Resource updated."
                    redirect $ ResourceR resId
                -- An authenticated, unprivileged user is the same as an
                -- unauthenticated user - their edits result in pending
                -- edits.
                else doPendingEdit res
          where
            doPendingEdit :: Resource -> Handler Html
            doPendingEdit Resource{..} = do
                pendingEditField resourceTitle     newTitle     EditTitle
                pendingEditField resourceAuthor    newAuthor    EditAuthor
                pendingEditField resourcePublished newPublished EditPublished
                pendingEditField resourceType      newType      EditType

                oldTags <- S.fromList . map tagText <$> runDB (getResourceTags resId)
                insertEditTags newTags oldTags EditAddTag    -- find any NEW not in OLD: pending ADD.
                insertEditTags oldTags newTags EditRemoveTag -- find any OLD not in NEW: pending REMOVE.
                setMessage "Your edit has been submitted for approval. Thanks!"
                redirect $ ResourceR resId
              where
                pendingEditField :: (Eq a, PersistEntity val, PersistEntityBackend val ~ SqlBackend)
                    => a                        -- Old field value
                    -> a                        -- New field value
                    -> (ResourceId -> a -> val) -- PersistEntity constructor
                    -> Handler ()
                pendingEditField oldValue newValue entityConstructor =
                    when (oldValue /= newValue) $
                        void . runDB . insertUnique $ entityConstructor resId newValue

                -- If we find any needles NOT in the haystack, insert the needle into the database
                -- with the supplied constructor.
                insertEditTags :: (PersistEntity val, PersistEntityBackend val ~ SqlBackend)
                               => Set Text
                               -> Set Text
                               -> (ResourceId -> Text -> val)
                               -> Handler ()
                insertEditTags needles haystack entityConstructor =
                    mapM_ (\needle ->
                        unless (S.member needle haystack) $
                            (void . runDB . insertUnique $ entityConstructor resId needle)) needles
        FormFailure errs -> do
            setMessage . toHtml $ "Form error: " <> intercalate ", " errs
            redirect $ ResourceR resId
        FormMissing -> redirect $ ResourceR resId
