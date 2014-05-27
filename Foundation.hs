module Foundation where

import           Control.Concurrent          (MVar)
import qualified Database.Persist
import           Database.Persist.Sql        (SqlPersistT)
import           Data.Map                    (Map)
import           Data.Text                   (Text)
import           Model
import           Network.HTTP.Client.Conduit (Manager, HasHttpManager (getHttpManager))
import           Prelude
import           Settings                    (Extra(..), widgetFile)
import qualified Settings
import           Settings.Development        (development)
import           Settings.StaticFiles
import           Text.Jasmine                (minifym)
import           Text.Hamlet                 (hamletFile)
import           Yesod
import           Yesod.Core.Types            (Logger)
import           Yesod.Static
import           Yesod.Auth
import           Yesod.Auth.BrowserId
import           Yesod.Auth.GoogleEmail
import           Yesod.Default.Config
import           Yesod.Default.Util          (addStaticContentExternal)

data App = App
    -- TODO: prepend 'app'
    { settings      :: AppConfig DefaultEnv Extra
    , getStatic     :: Static                                                  -- ^ Settings for static file serving.
    , connPool      :: Database.Persist.PersistConfigPool Settings.PersistConf -- ^ Database connection pool.
    , httpManager   :: Manager
    , persistConfig :: Settings.PersistConf
    , appLogger     :: Logger

    , appUsersMap   :: MVar (Map UserId User)
    }

instance HasHttpManager App where
    getHttpManager = httpManager

-- Set up i18n messages. See the message folder.
mkMessage "App" "messages" "en"

-- This is where we define all of the routes in our application. For a full
-- explanation of the syntax, please see:
-- http://www.yesodweb.com/book/routing-and-handlers
--
-- Note that this is really half the story; in Application.hs, mkYesodDispatch
-- generates the rest of the code. Please see the linked documentation for an
-- explanation for this split.
mkYesodData "App" $(parseRoutesFile "config/routes")

type Form x = Html -> MForm (HandlerT App IO) (FormResult x, Widget)

-- Please see the documentation for the Yesod typeclass. There are a number
-- of settings which can be configured by overriding methods here.
instance Yesod App where
    approot = ApprootMaster $ appRoot . settings

    -- Store session data on the client in encrypted cookies,
    -- default session idle timeout is 120 minutes
    makeSessionBackend _ = fmap Just $ defaultClientSessionBackend
        120    -- timeout in minutes
        "config/client_session_key.aes"

    defaultLayout widget = do
        mmsg <- getMessage

        -- We break up the default layout into two components:
        -- default-layout is the contents of the body tag, and
        -- default-layout-wrapper is the entire page. Since the final
        -- value passed to hamletToRepHtml cannot be a widget, this allows
        -- you to use normal widget features in default-layout.

        pc <- widgetToPageContent $ do
            $(combineStylesheets 'StaticR
                [ css_normalize_css
                , css_bootstrap_css
                ])
            $(widgetFile "default-layout")
        giveUrlRenderer $(hamletFile "templates/default-layout-wrapper.hamlet")

    -- This is done to provide an optimization for serving static files from
    -- a separate domain. Please see the staticRoot setting in Settings.hs
    urlRenderOverride y (StaticR s) =
        Just $ uncurry (joinPath y (Settings.staticRoot $ settings y)) $ renderRoute s
    urlRenderOverride _ _ = Nothing

    -- The page to be redirected to when authentication is required.
    authRoute _ = Just $ AuthR LoginR

    -- This function creates static content files in the static folder
    -- and names them based on a hash of their content. This allows
    -- expiration dates to be set far in the future without worry of
    -- users receiving stale content.
    addStaticContent =
        addStaticContentExternal minifym genFileName Settings.staticDir (StaticR . flip StaticRoute [])
      where
        -- Generate a unique filename based on the content itself
        genFileName lbs
            | development = "autogen-" ++ base64md5 lbs
            | otherwise   = base64md5 lbs

    -- Place Javascript at bottom of the body tag so the rest of the page loads first
    jsLoader _ = BottomOfBody

    -- What messages should be logged. The following includes all messages when
    -- in development, and warnings and errors in production.
    shouldLog _ _source level =
        development || level == LevelWarn || level == LevelError

    makeLogger = return . appLogger

    isAuthorized = isAuthorized_

-- Some pages require authorization.
isAuthorized_ :: Route App -> Bool -> Handler AuthResult
isAuthorized_ SubmitR       _    = requiresAuthorization
isAuthorized_ (ResourceR _) True = requiresAuthorization
isAuthorized_ _             _    = return Authorized

requiresAuthorization :: Handler AuthResult
requiresAuthorization = maybeAuth >>= maybe (return AuthenticationRequired) (const $ return Authorized)

-- How to run database actions.
instance YesodPersist App where
    type YesodPersistBackend App = SqlPersistT
    runDB = defaultRunDB persistConfig connPool

instance YesodPersistRunner App where
    getDBRunner = defaultGetDBRunner connPool

instance YesodAuth App where
    type AuthId App = UserId
    loginDest  _ = HomeR -- Where to send a user after successful login
    logoutDest _ = HomeR -- Where to send a user after logout

    -- TODO: redirect to profile page
    getAuthId creds = runDB $
        getBy (UniqueUser $ credsIdent creds) >>= \case
            Just (Entity uid _) -> return (Just uid)
            Nothing -> do
                uid <- insert User
                    { userName        = credsIdent creds
                    , userDisplayName = Nothing
                    }
                return (Just uid)

    -- You can add other plugins like BrowserID, email or OAuth here
    authPlugins _ = [authBrowserId def, authGoogleEmail]

    authHttpManager = httpManager

-- This instance is required to use forms. You can modify renderMessage to
-- achieve customized and internationalized form validation messages.
instance RenderMessage App FormMessage where
    renderMessage _ _ = defaultFormMessage

-- | Get the 'Extra' value, used to hold data from the settings.yml file.
getExtra :: Handler Extra
getExtra = fmap (appExtra . settings) getYesod

-- Note: previous versions of the scaffolding included a deliver function to
-- send emails. Unfortunately, there are too many different options for us to
-- give a reasonable default. Instead, the information is available on the
-- wiki:
--
-- https://github.com/yesodweb/yesod/wiki/Sending-email
