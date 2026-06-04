from pydantic import BaseModel, ConfigDict


class ProgramCategoryRead(BaseModel):
    """Wire shape matching iOS `ProgramCategory`."""

    model_config = ConfigDict(from_attributes=True)

    category_id: int
    category_name: str


class KeywordRead(BaseModel):
    """Wire shape matching iOS `Keyword`."""

    model_config = ConfigDict(from_attributes=True)

    keyword_id: int
    category_id: int
    keyword_name: str
