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


class CommitmentFrequency(StrEnum):
    """How often a program expects volunteers to show up (wire values match iOS)."""

    WEEKLY = "weekly"
    MONTHLY = "monthly"


class CommitmentDuration(StrEnum):
    """Expected length of commitment in months, as filter buckets (wire values
    match iOS CommitmentDuration)."""

    UNDER_2 = "under_2"
    THREE_TO_SIX = "three_to_six"
    SEVEN_TO_NINE = "seven_to_nine"
    CONTINUOUS = "continuous"


class TeamSize(StrEnum):
    """Team-size preference buckets used as a `GET /programs` filter. Not stored
    on the program; mapped to ``max_volunteers`` ranges at query time (wire
    values match iOS TeamSize)."""

    SMALL = "small"  # 2-3
    MEDIUM = "medium"  # 4-6
    LARGE = "large"  # 7-10
    OPEN = "open"  # 11+
