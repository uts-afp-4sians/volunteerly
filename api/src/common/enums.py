from enum import StrEnum


class ProgramStatus(StrEnum):
    """Lifecycle status of a program (wire values match iOS ProgramStatus)."""

    DRAFT = "draft"
    OPEN = "open"
    FULL = "full"
    CLOSED = "closed"
    CANCELLED = "cancelled"


class ParticipationStatus(StrEnum):
    """Status of a user's participation in a program."""

    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    WITHDRAWN = "withdrawn"
