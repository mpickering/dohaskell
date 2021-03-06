module Model.ResourceType where

import Prelude

import Database.Persist.TH (derivePersistField)
import Data.Text           (Text)
import Text.Blaze          (ToMarkup, preEscapedToMarkup, toMarkup)

data ResourceType
    = BlogPost
    | CommunitySite
    | Dissertation
    | ExperienceReport
    | ExtendedExample
    | ForumPost
    | FunctionalPearl
    | LectureNotes
    | MastersThesis
    | MetaResource
    | QAWebsite
    | ResearchPaper
    | ResearchPaperLite
    | SurveyArticle
    | Textbook
    | VideoLecture
    deriving (Bounded, Enum, Eq, Ord, Read, Show)
derivePersistField "ResourceType"

-- Reuse instance ToMarkup Text
instance ToMarkup ResourceType where
    toMarkup = toMarkup . descResourceType
    preEscapedToMarkup = toMarkup . descResourceType

-- Describe a resource type in a short sentence.
descResourceType :: ResourceType -> Text
descResourceType BlogPost          = "Blog post"
descResourceType CommunitySite     = "Community website"
descResourceType Dissertation      = "Dissertation"
descResourceType ExperienceReport  = "Experience report"
descResourceType ExtendedExample   = "Extended example/tutorial"
descResourceType ForumPost         = "Forum post (e.g. Reddit comment)"
descResourceType FunctionalPearl   = "Functional pearl"
descResourceType LectureNotes      = "Lecture slides/notes"
descResourceType MastersThesis     = "Master's thesis"
descResourceType MetaResource      = "Meta-resource"
descResourceType QAWebsite         = "Q&A website"
descResourceType ResearchPaper     = "Research paper"
descResourceType ResearchPaperLite = "Research paper lite"
descResourceType SurveyArticle     = "Survey article"
descResourceType Textbook          = "Textbook"
descResourceType VideoLecture      = "Video lecture/presentation"
