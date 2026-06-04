"""Import every ORM model so ``Base.metadata`` is fully populated.

Used by Alembic autogeneration, the test database setup, and the seed script.
"""

from src.categories.model import Keyword, ProgramCategory
from src.forum.model import ForumComment, ForumPost
from src.locations.model import Location
from src.programs.model import (
    Program,
    ProgramBookmark,
    ProgramKeyword,
    ProgramParticipation,
)
from src.users.model import User, UserInterest, UserProfile

__all__ = [
    "ForumComment",
    "ForumPost",
    "Keyword",
    "Location",
    "Program",
    "ProgramBookmark",
    "ProgramCategory",
    "ProgramKeyword",
    "ProgramParticipation",
    "User",
    "UserInterest",
    "UserProfile",
]
